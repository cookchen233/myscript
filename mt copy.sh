#!/bin/bash
# 简化合并推送测试环境的 git 命令

# 可使用像 git commit 那样的多个 -m 参数: mt test -m "消息主题 (subject)" -m "消息内容 (body)"
# 如果没有 -m 参数, 默认取最后一次的消息主题
# 如果是第二次提交, 可直接使用: mt test -ma "消息内容", ma 会在消息主题后追加消息内容, 并且因为没有传 m, 会直接取上一次的消息主题. 这样就免去重复输入消息主题的麻烦.

# 示例:
# 第一次提交并推送到 test: mt test -m "DY-444: 这是一个需求" -m "详细内容"
# 第二次: mt test -ma "又修改了点东西"

# 说明: git 的 commit -m 参数是有格式的: <type>(<scope>): <subject>// 空一行<body>// 空一行<footer>.
# 我们用 PingCode 编号直接代替了 <type>(<scope>): <subject>, 省略 <footer>.
# 说明: git commit -m 参数值官方约定格式: <type>(<scope>): <subject>// 空一行<body>// 空一行<footer>.
# git log 命令的格式化参数 %s 是主题, %b 是 body, %B 是全部, 一般的图形化软件列表页默认显示主题 %s.

# set -- -t "目标分支" -m "信息主题 (subject)" -m "信息内容 (content)" -ma "追加信息内容(不传 -m 时, subject 取上一次的)"

# validate branch
if ! branch=$(git branch --show-current); then
  echo -e "\033[1;31m仓库信息异常, 请检查\033[1;0m"
  exit 1
fi
case $branch in
'develop' | 'test' | 'release' | 'main' | 'master')
  echo -e "\033[1;31m当前 $branch 为非任务分支 , 请切换到您的任务分支\033[1;0m"
  exit 1
  ;;
esac

target=""
messages=()
message_append=""

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
# branch aliases
if [[ $target == "dev" ]]; then
  target="feature/unit_test"
elif [[ $target == "test" ]]; then
  target="feature/merge1016"
fi
# use the last commit subject if -m is not specified
if [ ${#messages[@]} -eq 0 ]; then
  messages+=("$(git log --pretty=format:'%s' origin/develop.. -1)")
fi
if [[ -n "$message_append" ]]; then
  messages+=("$message_append")
fi
messages_str=$(printf "%s\n\n\n" "${messages[@]}")
messages_str="${messages_str%"$'\n\n\n'"}"

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

# switch to the target branch
echo -e "\033[1;34m切换到 $target \033[1;0m"
git branch -D "$target"
git fetch --all && git fetch -p origin
if ! git checkout "$target"; then
  echo -e "\033[1;31m切换失败, 请检查\033[1;0m"
  exit 1
fi

# merge
echo -e "\033[1;34m合并 $branch 到 ${target}\033[1;0m"
if ! git merge "$branch" --no-ff --allow-unrelated-histories -m "$messages_str"; then
  echo -e "\033[1;31m合并失败, 请检查\033[1;0m"
  exit 1
fi

# push
echo -e "\033[1;34m推送 $target ...\033[1;0m"
max_attempts=2
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if git push; then
    break
  elif [ $attempt -ge $max_attempts ]; then
    echo -e "\033[1;31m推送失败, 请手动重试push命令\033[1;0m"
    exit 1
  fi
done

#执行yzl脚本

#end

# switch back to the task branch
echo -e "\033[1;34m切回到 ${branch}\033[1;0m"
git checkout "$branch"
git branch -D "$target"
git fetch --all && git fetch -p origin

exit $?
