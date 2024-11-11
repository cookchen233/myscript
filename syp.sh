#!/bin/bash
# 合并+推送+同步远程文件的快捷命令

# 使用方法: 在项目根目录执行 sy <目标分支>
# 说明: 若当前处于任务分支, 将自动切换到目标分支后合并任务分支, 如果已经在目标分支, 则仅推送+同步
# 配置: 项目根目录放置对应的目标服务器配置, 文件名为 sync_目标服务器(目标分支).json, 如推往 master 就建立 sync_master.json, 推往客户服务器就建立 sync_client.json, 同时要建立 client 分支

# 创建临时目录用于缓存
CACHE_DIR="/tmp/sync_script_cache"
mkdir -p "$CACHE_DIR"

# 创建临时文件用于同步状态
SYNC_STATUS_FILE=$(mktemp)
GIT_STATUS_FILE=$(mktemp)

cleanup() {
    rm -f "$SYNC_STATUS_FILE" "$GIT_STATUS_FILE"
    # 清理SSH控制主连接
    if [[ -n "$REMOTE_USER" && -n "$REMOTE_IP" && -n "$PORT" ]]; then
        ssh -O stop -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" 2>/dev/null
    fi
}
trap cleanup EXIT

# SSH控制主连接
setup_ssh_controlmaster() {
    local remote_user=$1
    local remote_ip=$2
    local port=$3
    
    mkdir -p ~/.ssh/controlmasters
    
    ssh -nNf -o ControlMaster=yes \
           -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" \
           -o ControlPersist=5m \
           -p "$port" "$remote_user@$remote_ip"
}

# 定义计时函数
timer_start() {
    local timer_name=${1:-"总"}
    local safe_name=$(echo "$timer_name" | md5 2>/dev/null || echo "$timer_name" | md5sum | cut -d' ' -f1)
    if [[ "$(uname)" == "Darwin" ]]; then
        eval "timer_${safe_name}=$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')"
    else
        eval "timer_${safe_name}=$(date +%s.%N)"
    fi
}

timer_end() {
    local timer_name=${1:-"总"}
    local safe_name=$(echo "$timer_name" | md5 2>/dev/null || echo "$timer_name" | md5sum | cut -d' ' -f1)
    local start_var="timer_${safe_name}"
    local start_time=${!start_var}
    
    if [[ -z "$start_time" ]]; then
        echo "错误: 计时器 '${timer_name}' 未启动" >&2
        return 1
    fi
    
    if [[ "$(uname)" == "Darwin" ]]; then
        end_time=$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')
    else
        end_time=$(date +%s.%N)
    fi
    
    execution_time=$(printf "%.2f" $(echo "$end_time - $start_time" | bc))
    echo "${timer_name}耗时: ${execution_time}s"
    
    unset "$start_var"
}

# 缓存配置文件读取
read_config() {
    local json_file_name=$1
    local cache_file="$CACHE_DIR/${json_file_name}.cache"
    
    if [[ ! -f "$cache_file" ]] || [[ "$json_file_name" -nt "$cache_file" ]]; then
        {
            jq -r '.path,.to_path,.ip,.user,.port,.root' "$json_file_name" > "$cache_file"
        } || {
            echo -e "\033[1;31m请添加配置文件 $json_file_name\033[1;0m"
            return 1
        }
    fi
    
    {
        read -r PUSH_PATH
        read -r TO_PATH
        read -r REMOTE_IP
        read -r REMOTE_USER
        read -r _PORT
        read -r _ROOT
    } < "$cache_file"
    
    return 0
}

# rsync同步函数
do_rsync() {
    local target=$1
    local only_diff=$2
    local branch_for_diff=$3  # 新增参数，用于差异同步时的分支信息

    timer_start "rsync同步"

    HOME_WORK_PATH=$(pwd)
    SERVER_HOME_WORK_PATH="/www/wwwroot/"
    PORT=22

    json_file_name="sync_${target}.json"
    if ! read_config "$json_file_name"; then
        echo "1" > "$SYNC_STATUS_FILE"
        return 1
    fi

    if [ "$_ROOT" != null ]; then
        SERVER_HOME_WORK_PATH=$_ROOT
    fi

    if [ "$_PORT" != null ]; then
        PORT=$_PORT
    fi

    LOCAL_DIR=$HOME_WORK_PATH$PUSH_PATH
    REMOTE_DIR=$SERVER_HOME_WORK_PATH$TO_PATH

    setup_ssh_controlmaster "$REMOTE_USER" "$REMOTE_IP" "$PORT"

    if [ "$only_diff" != true ]; then
        # 全量同步逻辑
        exclude_items=(
            ".user.ini" ".env" ".git" ".DS_Store" ".idea" ".vscode"
            ".hbuilderx" ".settings" ".buildpath" ".project" ".history"
            "Thumbs.db" "log/" "logs/" "upload/" "uploads/" "node_modules/"
            "runtime/" "/cert/" "test/" "tests/" "/build" "/uni_modules/"
            "/unpackage/" ".tmp.driveupload" "tmp.drivedownload"
            "**/*.log" "**/*.pid"
        )

        exclude_params=""
        for item in "${exclude_items[@]}"; do
            exclude_params="$exclude_params --exclude='$item'"
        done

        if ! eval "rsync -avzP \
            --rsh=\"ssh -p $PORT -o ControlPath=~/.ssh/controlmasters/%r@%h:%p\" \
            --no-perms --no-owner --no-group \
            --compress-level=9 \
            --stats \
            $exclude_params \
            \"$LOCAL_DIR\" \"$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR\""; then
            echo "1" > "$SYNC_STATUS_FILE"
            return 1
        fi

        find_conditions=""
        for item in "${exclude_items[@]}"; do
            if [[ ! $item =~ /$ ]]; then
                find_conditions="$find_conditions ! -name '$item'"
            fi
        done

        if ! ssh -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" \
            "find $REMOTE_DIR -type d -exec chmod 755 {} + ; \
             find $REMOTE_DIR -type f $find_conditions -exec chmod 644 {} + ; \
             find $REMOTE_DIR $find_conditions -exec chown www:www {} +"; then
            echo "1" > "$SYNC_STATUS_FILE"
            return 1
        fi
    else
        # 差异同步逻辑
        files=$(git diff --name-only HEAD~1...HEAD)
        if [ -n "$files" ]; then
            temp_file_list=$(mktemp)
            echo "$files" > "$temp_file_list"

            if ! rsync -avz --rsh="ssh -p $PORT -o ControlPath=~/.ssh/controlmasters/%r@%h:%p" \
                --no-perms --no-owner --no-group \
                --files-from="$temp_file_list" \
                "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"; then
                rm -f "$temp_file_list"
                echo "1" > "$SYNC_STATUS_FILE"
                return 1
            fi

            rm -f "$temp_file_list"

            if ! ssh -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" \
                "find $REMOTE_DIR -type d -exec chmod 755 {} + ; \
                 find $REMOTE_DIR -type f ! -name '.user.ini' -exec chmod 644 {} + ; \
                 find $REMOTE_DIR ! -name '.user.ini' -exec chown www:www {} +"; then
                echo "1" > "$SYNC_STATUS_FILE"
                return 1
            fi
        fi
    fi

    echo "0" > "$SYNC_STATUS_FILE"
    timer_end "rsync同步"
}

# Git操作函数
do_git_operations() {
    local target=$1
    local branch=$2
    local messages_str=$3
    local has_remote_branch=$4

    timer_start "git操作"

    # merge
    echo -e "\033[1;34m合并 $branch 到 ${target}\033[1;0m"
    if ! git merge "$branch" --no-ff --allow-unrelated-histories -m "$messages_str"; then
        echo "1" > "$GIT_STATUS_FILE"
        return 1
    fi

    # push
    if $has_remote_branch; then
        echo -e "\033[1;34m推送 $target ...\033[1;0m"
        max_attempts=2
        for ((attempt = 1; attempt <= max_attempts; attempt++)); do
            if git push; then
                break
            elif [ "$attempt" -ge "$max_attempts" ]; then
                echo -e "\033[1;31m推送失败, 请手动重试push命令\033[1;0m"
                echo "1" > "$GIT_STATUS_FILE"
                return 1
            fi
        done
    else
        echo -e "\033[1;33m未检测到远程分支，跳过推送步骤\033[0m"
    fi

    echo "0" > "$GIT_STATUS_FILE"
    timer_end "git操作"
}

timer_start

# 获取当前脚本文件的最后修改时间
version=$(date -r "$0" "+%Y%m%d")
echo -e "\033[1;34mVersion: $version \033[1;0m\n"

# validate branch
if ! branch=$(git branch --show-current); then
    echo -e "\033[1;31m仓库信息异常, 请检查\033[1;0m"
    exit 1
fi

case $branch in
    'develop'|'test'|'release'|'main'|'master'|'partner')
        echo -e "\033[1;31m当前 $branch 为非任务分支 , 请切换到您的任务分支\033[1;0m"
        exit 1
        ;;
esac

# 解析命令行参数
target=""
messages=()
message_append=""
only_diff=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t)
            target="$2"
            shift 2
            ;;
        -m)
            messages+=("$2")
            shift 2
            ;;
        -ma)
            message_append="$2"
            shift 2
            ;;
        diff)
            only_diff=true
            shift
            ;;
        *)
            if [ -z "$target" ]; then
                target="$1"
            elif [ ${#messages[@]} -eq 0 ]; then
                messages+=("$1")
            else
                echo "未知选项或参数: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$target" ]; then
    echo "错误: 目标分支参数是必需的 (第一个或 -t)"
    exit 1
fi

if [[ "$branch" == "$target" ]]; then
    echo -e "\033[1;31m禁止直接推送分支\033[1;0m"
    exit 1
fi

# 后台预加载远程分支信息
git fetch --all &
FETCH_PID=$!

# 如果没有指定 -m，则使用最后一次提交信息
if [ ${#messages[@]} -eq 0 ]; then
    default_branch=$( \
        git show-ref --verify --quiet refs/heads/main && echo "main" || \
        git show-ref --verify --quiet refs/heads/master && echo "master" || \
        git ls-remote --heads origin main 2>/dev/null | grep -q main && echo "main" || \
        echo "master")
    messages+=("$(git log --pretty=format:'%s' -1 origin/"${default_branch}" || git rev-parse --abbrev-ref HEAD || echo "Update")")
    echo -e "\033[1;34m没有指定 -m 参数, 将使用最后一次提交信息\033[1;0m"
fi

# 追加额外信息
if [[ -n "$message_append" ]]; then
    messages+=("$message_append")
fi

# 合并消息
messages_str=$(printf "%s\n\n\n" "${messages[@]}")
messages_str="${messages_str%"$'\n\n\n'"}"
messages_str=${messages_str:-"脚本自动提交"}

# commit
echo -e "\033[1;34m提交 '$messages_str' ...\033[1;0m"
git_status=$(git -c color.status=always status)
if [[ $git_status != *"nothing to commit"* && $git_status != *"无文件要提交，干净的工作区"* ]]; then
    echo "$git_status"
    if ! (git add --all && git commit -m "$messages_str"); then
        echo -e "\033[1;31m提交失败, 请检查\033[1;0m"
        exit 1
    fi
fi

# 等待fetch完成
wait $FETCH_PID

# 检查远程分支是否存在
has_remote_branch=$(git ls-remote --heads origin "$target" | grep -q . && echo true || echo false)

# switch to the target branch
echo -e "\033[1;34m切换到 $target \033[1;0m"
if $has_remote_branch; then
    echo -e "\033[1;34m检测到远程分支 $target \033[1;0m"
    echo -e "\033[1;34m删除本地分支, 获取最新远程分支 $target \033[1;0m"
    git branch -D "$target" 2>/dev/null || true
    if ! git checkout "$target"; then
        echo -e "\033[1;31m切换分支失败\033[1;0m"
        exit 1
    fi
else
    echo -e "\033[1;34m远程分支 $target 不存在, 请注意本地代码的保管 \033[1;0m"
    if git show-ref --verify --quiet "refs/heads/$target"; then
        if ! git checkout "$target"; then
            echo -e "\033[1;31m切换分支失败\033[1;0m"
            exit 1
        fi
    else
        echo -e "\033[1;31m本地和远程都没有找到该分支: $target\033[1;0m"
        exit 1
    fi
fi

# 并行执行git操作和rsync同步
do_git_operations "$target" "$branch" "$messages_str" "$has_remote_branch" &
GIT_PID=$!

do_rsync "$target" "$only_diff" "$branch" &
RSYNC_PID=$!

# 等待两个进程完成
wait $GIT_PID
git_status=$(<"$GIT_STATUS_FILE")
wait $RSYNC_PID
sync_status=$(<"$SYNC_STATUS_FILE")

# 检查执行结果
if [ "$git_status" != "0" ] || [ "$sync_status" != "0" ]; then
    echo -e "\033[1;31m操作失败\033[1;0m"
    # 切回原分支
    echo -e "\033[1;34m切回到 ${branch}\033[1;0m"
    if ! git checkout "$branch"; then
        echo -e "\033[1;31m切换分支失败\033[1;0m"
        exit 1
    fi
    if $has_remote_branch; then
        echo -e "\033[1;34m删除本地分支 ${target}\033[1;0m"
        git branch -D "$target"
        git fetch -p origin &
    fi
    exit 1
fi

# 成功后切回原分支
echo -e "\033[1;34m切回到 ${branch}\033[1;0m"
if ! git checkout "$branch"; then
    echo -e "\033[1;31m切换分支失败\033[1;0m"
    exit 1
fi

if $has_remote_branch; then
    echo -e "\033[1;34m删除本地分支 ${target}\033[1;0m"
    git branch -D "$target"
    git fetch -p origin &
fi

timer_end

exit 0