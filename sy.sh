#!/bin/bash
# 合并+推送+同步远程文件的快捷命令

# 使用方法: 在项目根目录执行 sy <目标分支>
# 说明: 若当前处于任务分支, 将自动切换到目标分支后合并任务分支, 如果已经在目标分支, 则仅推送+同步
# 配置: 项目根目录放置对应的目标服务器配置, 文件名为 sync_目标服务器(目标分支).json, 如推往 master 就建立 sync_master.json, 推往客户服务器就建立 sync_client.json, 同时要建立 client 分支
# 可使用像 git commit 那样的多个 -m 参数, 如: sy test -m "消息主题 (subject)" -m "消息内容 (body)"
# 如果没有 -m 参数, 默认取最后一次的消息主题
# 如果已经合并过一次, 可使用 -ma 如: sy test -ma "消息内容2", 这将沿用上一次的消息主题

# 创建临时目录用于缓存
CACHE_DIR="/tmp/sync_script_cache"
mkdir -p "$CACHE_DIR"

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
    
    # 如果缓存文件不存在或配置文件比缓存新，则重新读取
    if [[ ! -f "$cache_file" ]] || [[ "$json_file_name" -nt "$cache_file" ]]; then
        {
            jq -r '.path,.to_path,.ip,.user,.port,.root' "$json_file_name" > "$cache_file"
        } || {
            echo -e "\033[1;31m请添加配置文件 $json_file_name\033[1;0m"
            return 1
        }
    fi
    
    # 读取缓存的配置
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
    git branch -D "$target"
    git fetch -p origin &  # 后台执行清理
  fi

  # 清理SSH控制主连接
  if [[ -n "$REMOTE_USER" && -n "$REMOTE_IP" && -n "$PORT" ]]; then
    ssh -O stop -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" 2>/dev/null
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

if [ "$is_all" == true ]; then
  read -p "是否要进行全量同步？(将覆盖服务器所有文件, 请注意某些文件对服务器的影响, 如 .env, /runtime, /node_modules, /logs 等) [y/n]: " choice
  if [ -z "$choice" ] || [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    # 定义需要排除的文件和目录
    exclude_items=(
      ".user.ini"
      ".env"
      ".git"
      ".DS_Store"
      ".idea"
      ".vscode"
      ".hbuilderx"
      ".settings"
      ".buildpath"
      ".project"
      ".history"
      "Thumbs.db"
      "log/"
      "logs/"
      "upload/"
      "uploads/"
      "node_modules/"
      "runtime/"
      "/cert/"
      "test/"
      "tests/"
      "/build"
      "/uni_modules/"
      "/unpackage/"
      ".tmp.driveupload"
      "tmp.drivedownload"
      "**/*.log"
      "**/*.pid"
    )

    # 构建 rsync 的 exclude 参数
    exclude_params=""
    for item in "${exclude_items[@]}"; do
      exclude_params="$exclude_params --exclude='$item'"
    done

    # rsync 同步文件，使用SSH控制主连接
    echo -e "\033[1;34m同步所有文件: \n$LOCAL_DIR => $REMOTE_DIR\033[1;0m"
    rsync_output=$(eval "rsync -avzP \
        --rsh=\"ssh -p $PORT -o ControlPath=~/.ssh/controlmasters/%r@%h:%p\" \
        --no-perms --no-owner --no-group \
        --compress-level=9 \
        --stats \
        $exclude_params \
        \"$LOCAL_DIR\" \"$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR\"" 2>&1)
    ret=$?

    # 始终显示 rsync 的输出
    echo "$rsync_output"

    # 仅在失败时显示错误信息
    ((ret != 0)) && {
      if echo "$rsync_output" | grep -q "Connection refused"; then
        echo -e "\033[1;31mrsync同步失败: SSH连接被拒绝，请检查:\n\
    1. SSH连接信息(用户名/IP/端口)是否正确\n\
    2. 目标服务器SSH服务是否正常运行\n\
    3. 防火墙是否允许该端口连接\033[1;0m"
      else
        echo -e "\033[1;31mrsync同步失败: 文件传输过程中发生错误\033[1;0m"
      fi
      switch_back 1
    }

    # 构建 find 命令的条件
    find_conditions=""
    for item in "${exclude_items[@]}"; do
      if [[ ! $item =~ /$ ]]; then
        find_conditions="$find_conditions ! -name '$item'"
      fi
    done

    # 设置权限并捕获错误，使用SSH控制主连接
    if ! ssh -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" "find $REMOTE_DIR -type d -exec chmod 755 {} + ; find $REMOTE_DIR -type f $find_conditions -exec chmod 644 {} + ; find $REMOTE_DIR $find_conditions -exec chown www:www {} +"; then
      echo -e "\033[1;31m权限设置失败: 无法更改文件权限或所有者\033[1;0m"
      switch_back 1
    fi

  else
    echo -e "\033[1;31m已放弃同步\033[1;0m"
    switch_back 1
  fi

else
  # 获取所有改变的文件列表
  files=$(git diff --name-only HEAD~1...HEAD)

  echo "待同步的文件列表"
  echo "--------------------------------"
  echo -e "$files"
  echo "--------------------------------"
  # read -p "是否同步这些文件到服务器？(y/n): " choice
  choice="y"
  if [ -z "$choice" ] || [ "$choice" = "y" ] || [ "$choice" = "Y" ]; then
    # 创建临时文件列表
    temp_file_list=$(mktemp)
    echo "$files" > "$temp_file_list"

    # 使用rsync的--files-from选项批量同步文件
    rsync -avz --rsh="ssh -p $PORT -o ControlPath=~/.ssh/controlmasters/%r@%h:%p" \
          --no-perms --no-owner --no-group \
          --files-from="$temp_file_list" \
          "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"

    rm -f "$temp_file_list"

    # 设置权限，但排除 .user.ini 文件
    ssh -o ControlPath="~/.ssh/controlmasters/%r@%h:%p" -p "$PORT" "$REMOTE_USER@$REMOTE_IP" \
        "find $REMOTE_DIR -type d -exec chmod 755 {} + ; find $REMOTE_DIR -type f ! -name '.user.ini' -exec chmod 644 {} + ; find $REMOTE_DIR ! -name '.user.ini' -exec chown www:www {} +"
  else
    echo -e "\033[1;31m已放弃同步\033[1;0m"
    switch_back 1
  fi
fi

timer_end "rsync同步"

switch_back 0