#!/bin/bash
# 合并+推送+同步远程文件的快捷命令

# 使用方法: 在项目根目录执行 sy.sh <目标分支>
# 说明: 若当前处于任务分支, 将自动切换到目标分支后合并任务分支, 如果已经在目标分支, 则仅推送+同步
# 配置: 项目根目录放置对应的目标服务器配置, 文件名为 sync_目标服务器(目标分支).json, 如推往 master 就建立 sync_master.json, 推往客户服务器就建立 sync_client.json, 同时要建立 client 分支
# 可使用像 git commit 那样的多个 -m 参数, 如: sy test -m "消息主题 (subject)" -m "消息内容 (body)"
# 如果没有 -m 参数, 默认取最后一次的消息主题
# 如果已经合并过一次, 可使用 -ma 如: sy test -ma "消息内容2", 这将沿用上一次的消息主题

export LC_ALL=C
export LANG=C

unset http_proxy https_proxy all_proxy

# 创建临时目录用于缓存
# 获取项目根目录的唯一标识(使用目录路径的哈希值)
PROJECT_HASH=$((pwd | md5) || (pwd | md5sum) | cut -d' ' -f1)
CACHE_DIR="${HOME}/.cache/sync_script/${PROJECT_HASH}"
# 确保缓存目录存在
mkdir -p "$CACHE_DIR"

cleanup() {
    # 删除临时文件
    rm -f "$SYNC_STATUS_FILE" "$GIT_STATUS_FILE" "$GIT_ERROR_FILE" "$RSYNC_ERROR_FILE"
    
    # 清理过期的缓存文件(比如7天前的)
    find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null
    
    # 清理SSH连接
    if [[ -n "$REMOTE_USER" && -n "$REMOTE_IP" && -n "$PORT" ]]; then
        ssh -O stop -o ControlPath="$SSH_CONTROL_PATH" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" 2>/dev/null
    fi
}
trap cleanup EXIT

# SSH控制主连接
setup_ssh_controlmaster() {
    local remote_user=$1
    local remote_ip=$2
    local port=$3
    
    # 创建控制socket目录
    mkdir -p ~/.ssh/controlmasters
    
    # 设置SSH控制主连接
    ssh -nNf -o ControlMaster=yes \
           -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" \
           -o ControlPersist=5m \
           -p "$port" "$remote_user@$remote_ip"
}

# 定义计时函数，支持多个计时器
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
    
    if [[ ! -f "$json_file_name" ]]; then
    echo -e "\033[1;31m找不到配置文件 $json_file_name\033[0m"
    echo -e "\033[1;31m请创建配置文件，格式示例：\033[0m"
    
    # 先显示配置文件格式
    cat << 'EOF'
{
    "path": "/",
    "to_path": "project/",
    "ip": "118.25.213.111",
    "user": "username",
    "port": 22,
    "root": "/www/wwwroot/"
}
EOF
        
        # 再显示配置说明
        echo -e "配置说明:"
        echo -e "path      - 本地项目相对路径(通常为/)"
        echo -e "to_path   - 远程项目相对路径(相对于root)"
        echo -e "ip        - 服务器IP地址"
        echo -e "user      - SSH用户名"
        echo -e "port      - SSH端口"
        echo -e "root      - 远程根目录"
        return 1
    fi
    
    if [[ ! -f "$cache_file" ]] || [[ "$json_file_name" -nt "$cache_file" ]]; then
        if ! jq -r '.path,.to_path,.ip,.user,.port,.root' "$json_file_name" > "$cache_file.tmp" 2>/dev/null; then
            echo -e "\033[1;31m配置文件格式错误: $json_file_name\033[1;0m"
            return 1
        fi
        mv "$cache_file.tmp" "$cache_file"
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
'develop' | 'test' | 'release' | 'main' | 'master' | 'partner')
  echo -e "\033[1;31m当前 $branch 为非任务分支 , 请切换到您的任务分支\033[1;0m"
  exit 1
  ;;
esac

target=""
messages=()
message_append=""
is_all=false

# process parameters
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
  all)
    is_all=true
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

# switch back to the task branch
switch_back() {
  local exit_code="${1:-0}"

  echo -e "\033[1;34m切回到 ${branch}\033[1;0m"
  if ! git checkout "$branch"; then
    echo -e "\033[1;31m切换分支失败\033[1;0m"
    exit 1
  fi

  if $has_remote_branch; then
    echo -e "\033[1;34m删除本地分支 ${target}\033[1;0m"
    git branch -D "$target" &
    git fetch -p origin &
  fi

  # 清理SSH控制主连接
  if [[ -n "$REMOTE_USER" && -n "$REMOTE_IP" && -n "$PORT" ]]; then
    ssh -O stop -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" 2>/dev/null &
  fi

  timer_end

  exit "$exit_code"
}

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
    git branch -D "$target" 2>/dev/null || true  # 删除本地分支如果存在
    git checkout "$target"
else
    echo -e "\033[1;34m远程分支 $target 不存在, 请注意本地代码的保管 \033[1;0m"
    # 如果远程分支不存在，检查本地分支
    if git show-ref --verify --quiet "refs/heads/$target"; then
        git checkout "$target"
    else
        echo -e "\033[1;31m本地和远程都没有找到该分支: $target\033[1;0m"
        exit 1
    fi
fi

# merge
echo -e "\033[1;34m合并 $branch 到 ${target}\033[1;0m"
if ! git merge "$branch" --no-ff --allow-unrelated-histories -m "$messages_str"; then
  echo -e "\033[1;31m合并失败, 请检查\033[1;0m"
  switch_back 1
fi

timer_start "git推送"
# push
if $has_remote_branch; then
  echo -e "\033[1;34m推送 $target ...\033[1;0m"
  max_attempts=2
  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if git push; then
      echo -e "\033[1;32m推送完成\033[1;0m"
      break
    elif [ "$attempt" -ge "$max_attempts" ]; then
      echo -e "\033[1;31m推送失败, 请手动重试push命令\033[1;0m"
      switch_back 1
    fi
  done
else
  echo -e "\033[1;33m未检测到远程仓库，跳过推送步骤\033[0m"
fi
timer_end "git推送"

timer_start "rsync同步"
#执行yzl脚本#########################################################
HOME_WORK_PATH=$(pwd)
SERVER_HOME_WORK_PATH="/www/wwwroot/" #服务器基础目录
PORT=22

# 读取配置文件
json_file_name="sync_${target}.json"
if ! read_config "$json_file_name"; then
    switch_back 1
fi

if [ "$_ROOT" != null ]; then
  SERVER_HOME_WORK_PATH=$_ROOT
fi

if [ "$_PORT" != null ]; then
  PORT=$_PORT
fi

# 本地同步目录
LOCAL_DIR=$HOME_WORK_PATH$PUSH_PATH
# 服务器目录
REMOTE_DIR=$SERVER_HOME_WORK_PATH$TO_PATH

# 设置SSH控制主连接
setup_ssh_controlmaster "$REMOTE_USER" "$REMOTE_IP" "$PORT"

# 定义错误处理函数
handle_rsync_error() {
    local rsync_output="$1"
    local ret="$2"
    
    if echo "$rsync_output" | grep -qi "connection refused"; then
        echo -e "\033[1;31mrsync同步失败: SSH连接被拒绝，请检查:\n\
1. SSH连接信息(用户名/IP/端口)是否正确\n\
2. 目标服务器SSH服务是否正常运行\n\
3. 防火墙是否允许该端口连接\033[1;0m"
    elif echo "$rsync_output" | grep -qi "permission denied"; then
        echo -e "\033[1;31mrsync同步失败: 权限被拒绝，请检查:\n\
1. SSH密钥或密码是否正确\n\
2. 目标目录的读写权限\033[1;0m"
    elif echo "$rsync_output" | grep -qi "no such file or directory"; then
        echo -e "\033[1;31mrsync同步失败: 目录不存在，请检查:\n\
1. 源目录是否存在\n\
2. 目标目录是否存在或是否有权限创建\033[1;0m"
    elif echo "$rsync_output" | grep -qi "ssh_exchange_identification"; then
        echo -e "\033[1;31mrsync同步失败: SSH握手失败，请检查:\n\
1. SSH服务器配置是否正确\n\
2. 是否被服务器拒绝连接（如DenyHosts）\033[1;0m"
    else
        echo -e "\033[1;31mrsync同步失败: 发生未知错误（错误码：$ret）\n\
详细错误信息:\n$rsync_output\033[1;0m"
    fi
    switch_back 1
}

# 基础的rsync选项
declare -a base_rsync_opts=(
    --rsh="ssh -p $PORT -o ControlPath=~/.ssh/controlmasters/%r@%h:%p"
    --no-perms
    --no-owner
    --no-group
    --compress-level=9
    --stats
    --numeric-ids
    --inplace
    --no-whole-file
)

# 构建special_perm条件
declare -a special_perm_files=(
    ".user.ini"    # PHP user config
)
special_perm=""
for file in "${special_perm_files[@]}"; do
    special_perm+="! -name '$file' "
done

if [ "$is_all" == true ]; then
    # read -p "是否要进行全量同步？(将覆盖服务器所有文件, 请注意某些文件对服务器的影响, 如 .env, /runtime, /node_modules, /logs 等) [Y/n]: " choice
    choice="y"
    if [ -z "$choice" ] || [[ $choice =~ ^[Yy]$ ]]; then
        # 初始化排除项
        declare -a exclude_items=(
            ".git"
        )

        # 从.gitignore读取排除项
        if [[ -f .gitignore ]]; then
            while IFS= read -r line; do
                [[ -z "$line" || "$line" =~ ^# || "$line" =~ ^\.git ]] && continue
                # 不排除配置文件中指定的路径
                if [ "$line" == "${PUSH_PATH#/}" ] || [ "$line" == "${PUSH_PATH}" ]; then
                    continue
                fi
                exclude_items+=("$line")
            done < .gitignore
        else
            echo -e "\033[1;33m警告: .gitignore 文件不存在\033[0m" >&2
        fi

        # 构建全量同步的rsync选项
        declare -a rsync_opts=(
            "${base_rsync_opts[@]}"
            -azuP
            --compress-level=9
            --stats
        )

        # 添加排除项
        for item in "${exclude_items[@]}"; do
            rsync_opts+=(--exclude="$item")
        done

        # 执行文件同步
        echo -e "\033[1;34m[SYNC] 开始全量同步:\n$LOCAL_DIR => $REMOTE_DIR\033[0m"
        if rsync_output=$(rsync "${rsync_opts[@]}" \
            "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR/" 2>&1); then
            echo "$rsync_output"
        else
            echo "$rsync_output"
            handle_rsync_error "$rsync_output" $?
        fi

    else
        echo -e "\033[1;31m已取消同步\033[0m"
        switch_back 1
    fi

else
    # 获取变更文件列表
    if ! files=$(git diff --name-only HEAD~1...HEAD 2>/dev/null) || [ -z "$files" ]; then
        echo -e "\033[1;34m没有检测到文件变更，跳过同步\033[0m"
        switch_back 1
    fi

    echo -e "\033[1;34m待同步的文件列表:\033[0m"
    echo "--------------------------------"
    echo -e "$files"
    echo "--------------------------------"

    # 创建临时文件列表
    temp_file_list=$(mktemp)
    trap 'rm -f "$temp_file_list"' EXIT
    echo "$files" > "$temp_file_list"

    # 同步变更文件
    echo -e "\033[1;34m[SYNC] 开始增量同步...\033[0m"
    declare -a rsync_opts=(
        "${base_rsync_opts[@]}"
        -azP
        --files-from="$temp_file_list"
    )

    if rsync_output=$(rsync "${rsync_opts[@]}" \
        "$LOCAL_DIR/" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR/" 2>&1); then
        echo "$rsync_output"
    else
        echo "$rsync_output"
        handle_rsync_error "$rsync_output" $?
    fi
fi

# 统一的权限设置逻辑
echo -e "\033[1;34m[PERM] 设置权限...\033[0m"
ssh_cmd="cd '$REMOTE_DIR' && {
    find . -type d -exec chmod 755 {} + &
    find . -type f $special_perm -exec chmod 644 {} + &
    wait
    find . $special_perm -exec chown www:www {} +
}"

if ! ssh -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" \
        -p "$PORT" \
        "$REMOTE_USER@$REMOTE_IP" \
        "$ssh_cmd"; then
    echo -e "\033[1;31m[ERROR] 权限设置失败\033[0m" >&2
    switch_back 1
fi

echo -e "\033[1;32m同步完成\033[1;0m"
timer_end "rsync同步"

switch_back 0