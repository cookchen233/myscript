#!/bin/bash
# 合并+推送+同步远程文件的快捷命令

# 使用方法: 在项目根目录执行 sy <目标分支>
# 说明: 若当前处于任务分支, 将自动切换到目标分支后合并任务分支, 如果已经在目标分支, 则仅推送+同步
# 配置: 项目根目录放置对应的目标服务器配置, 文件名为 sync_目标服务器(目标分支).json, 如推往 master 就建立 sync_master.json, 推往客户服务器就建立 sync_client.json, 同时要建立 client 分支
# 可使用像 git commit 那样的多个 -m 参数, 如: sy test -m "消息主题 (subject)" -m "消息内容 (body)"
# 如果没有 -m 参数, 默认取最后一次的消息主题
# 如果已经合并过一次, 可使用 -ma 如: sy test -ma "消息内容2", 这将沿用上一次的消息主题

# 示例:
# 第一次合并到 test 分支: sy test -m "PR-444: 这是一个需求" -m "消息内容"
# 第二次: sy test -ma "又修改了点东西"

# 定义计时函数，支持多个计时器
timer_start() {
    local timer_name=${1:-"总"}
    # macOS 使用 md5 而不是 md5sum
    local safe_name=$(echo "$timer_name" | md5)
    if [[ "$(uname)" == "Darwin" ]]; then
        eval "timer_${safe_name}=$(perl -MTime::HiRes=time -e 'printf "%.3f\n", time')"
    else
        eval "timer_${safe_name}=$(date +%s.%N)"
    fi
}

timer_end() {
    local timer_name=${1:-"总"}
    local safe_name=$(echo "$timer_name" | md5)
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
only_diff=false

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
checkout_back() {
  local exit_code="${1:-0}"

  echo -e "\033[1;34m切回到 ${branch}\033[1;0m"
  if ! git checkout "$branch"; then
    echo -e "\033[1;31m切换分支失败\033[1;0m"
    exit 1
  fi

  if $has_remote_branch; then
    echo -e "\033[1;34m删除本地分支 ${target}\033[1;0m"
    git branch -D "$target"
    git fetch --all && git fetch -p origin
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

# 检查远程分支是否存在
has_remote_branch=$(git ls-remote --heads origin "$target" | grep -q . && echo true || echo false)

# switch to the target branch
echo -e "\033[1;34m切换到 $target \033[1;0m"
if $has_remote_branch; then
    echo -e "\033[1;34m检测到远程分支 $target \033[1;0m"
    echo -e "\033[1;34m删除本地分支, 获取最新远程分支 $target \033[1;0m"
    git branch -D "$target" 2>/dev/null || true  # 删除本地分支如果存在
    git fetch origin "$target"
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
  checkout_back 1
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
      checkout_back 1
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
{
  PUSH_PATH=$(jq -r '.path' "${json_file_name}")
  TO_PATH=$(jq -r '.to_path' "${json_file_name}")
  REMOTE_IP=$(jq -r '.ip' "${json_file_name}")
  REMOTE_USER=$(jq -r '.user' "${json_file_name}")
  _PORT=$(jq -r '.port' "${json_file_name}")
  _ROOT=$(jq -r '.root' "${json_file_name}")
} || {
  echo -e "\033[1;31m请添加配置文件 sync_${target}.json\033[1;0m"
  checkout_back 1
}

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

if [ "$only_diff" != true ]; then
  # read -p "是否要进行全量同步？(将覆盖服务器所有文件, 请注意某些文件对服务器的影响, 如 .env, /runtime, /node_modules, /logs 等) (y/n): " choice
  choice="y"
  if [ "$choice" == "y" ]; then
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
      "log/" # 不加斜杠会排除log.*等所有文件
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

    # 测试 SSH 连接
    # if ! ssh -p "$PORT" "$REMOTE_USER@$REMOTE_IP" "exit" 2>/dev/null; then
    #   echo -e "\033[1;31mSSH连接失败: 无法连接到远程服务器 $REMOTE_USER@$REMOTE_IP:$PORT\033[1;0m"
    #   checkout_back 1
    # fi

    # rsync 同步文件
    echo -e "\033[1;34m同步所有文件: \n$LOCAL_DIR => $REMOTE_DIR\033[1;0m"
    rsync_output=$(eval "rsync -avzP --rsh=\"ssh -p $PORT\" --no-perms --no-owner --no-group $exclude_params \"$LOCAL_DIR\" \"$REMOTE_USER@$REMOTE_IP:$REMOTE_DIR\"" 2>&1)
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
      checkout_back 1
    }

    # 构建 find 命令的条件
    find_conditions=""
    for item in "${exclude_items[@]}"; do
      if [[ ! $item =~ /$ ]]; then
        find_conditions="$find_conditions ! -name '$item'"
      fi
    done

    # 设置权限并捕获错误
    if ! ssh -p "$PORT" "$REMOTE_USER@$REMOTE_IP" "find $REMOTE_DIR -type d -exec chmod 755 {} + ; find $REMOTE_DIR -type f $find_conditions -exec chmod 644 {} + ; find $REMOTE_DIR $find_conditions -exec chown www:www {} +"; then
      echo -e "\033[1;31m权限设置失败: 无法更改文件权限或所有者\033[1;0m"
      checkout_back 1
    fi

  else
    echo -e "\033[1;31m已放弃同步\033[1;0m"
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

  if [ "$choice" == "y" ]; then
    for file in $files; do
      # 拼接文件路径
      FILE_TO_BACKUP="$LOCAL_DIR$file"
      SERVER_FILE_TO_BACKUP="$REMOTE_DIR$file"

      # 确保远程目录存在
      remote_dir=$(dirname "$SERVER_FILE_TO_BACKUP")
      ssh -p "$PORT" "$REMOTE_USER"@"$REMOTE_IP" "mkdir -p '$remote_dir'"

      # 检查是否为 .user.ini 文件
      if [[ "$file" == *".user.ini" ]]; then
        echo "检测到 .user.ini 文件，跳过同步"
        continue
      else
        # 使用rsync同步文件
        rsync -avz --rsh="ssh -p $PORT" --no-perms --no-owner --no-group "$FILE_TO_BACKUP" "$REMOTE_USER@$REMOTE_IP:$SERVER_FILE_TO_BACKUP"
      fi

      echo "已同步文件：$FILE_TO_BACKUP => $SERVER_FILE_TO_BACKUP"
    done

    # 设置权限，但排除 .user.ini 文件
    ssh -p "$PORT" "$REMOTE_USER"@"$REMOTE_IP" "find $REMOTE_DIR -type d -exec chmod 755 {} + ; find $REMOTE_DIR -type f ! -name '.user.ini' -exec chmod 644 {} + ; find $REMOTE_DIR ! -name '.user.ini' -exec chown www:www {} +"
  else
    echo "已放弃同步"
  fi
fi
#end################################################################
timer_end "rsync同步"

checkout_back 0
