#!/bin/bash
# 需安装： inotify-tools
#   dnf install -y inotify-tools
set -euo pipefail

# ================== 项目清单： 目录|构建命令 ==================
PROJECTS=(
  "/www/wwwroot/wnsafe.com|npm run build"
  "/www/wwwroot/cq.wnsafe.com|npm run build"
  # "/path/to/another|pnpm build"
)

# 防抖时间（秒）
DEBOUNCE=2

# 环境准备
export PATH="$(npm bin -g 2>/dev/null || true):/usr/local/bin:/usr/bin:/bin:$PATH"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true

# 通用日志（systemd journal）
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

if ! command -v inotifywait >/dev/null 2>&1; then
  log "[FATAL] inotifywait 未安装，请先安装 inotify-tools"
  exit 127
fi

# 忽略目录/文件
EXCLUDE_PAT='(^|/)\.git($|/)|(^|/)node_modules($|/)|(^|/)dist($|/)|(^|/)build($|/)|(^|/)\.next($|/)|(^|/)\.nuxt($|/)|\.swp$|~$|\.tmp$|\.log$'

# 定时器 PID
declare -A TIMER_PID_MAP

cleanup(){
  for pid in "${TIMER_PID_MAP[@]:-}"; do
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

# 启动构建（写入项目 build.log）
start_timer(){
  local project_dir="$1"   # 无尾斜杠
  local build_cmd="$2"
  local logfile="$project_dir/build.log"

  mkdir -p "$project_dir"
  touch "$logfile" 2>/dev/null || true

  # 取消已有定时器
  local pid="${TIMER_PID_MAP[$project_dir]:-}"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
  fi

  (
    sleep "$DEBOUNCE"
    {
      echo "$(date '+%Y-%m-%d %H:%M:%S') [$project_dir] 开始构建：$build_cmd"
      cd "$project_dir" && eval "$build_cmd"
      echo "$(date '+%Y-%m-%d %H:%M:%S') [$project_dir] 构建完成。"
    } >> "$logfile" 2>&1
  ) &
  TIMER_PID_MAP[$project_dir]=$!
}

# 校验路径
WATCH_PATHS=()
NORMALIZED_PROJECTS=()
for p in "${PROJECTS[@]}"; do
  dir="${p%%|*}"
  cmd="${p##*|}"
  dir="${dir%/}"

  if [[ ! -d "$dir" ]]; then
    log "[WARN] 目录不存在：$dir，自动创建"
    mkdir -p "$dir"
  fi

  WATCH_PATHS+=("$dir")
  NORMALIZED_PROJECTS+=("$dir|$cmd")
done

if [[ "${#WATCH_PATHS[@]}" -eq 0 ]]; then
  log "[FATAL] 没有可监听的目录，退出"
  exit 2
fi

log "[INFO] 启动目录监听："
for d in "${WATCH_PATHS[@]}"; do
  log "  - $d"
done

# 主循环
inotifywait -m -r \
  -e close_write,create,delete,move \
  --exclude "$EXCLUDE_PAT" \
  --format '%w|%e|%f' \
  "${WATCH_PATHS[@]}" 2>/dev/null |
while IFS='|' read -r path action file; do
  path_norm="${path%/}"

  for p in "${NORMALIZED_PROJECTS[@]}"; do
    dir="${p%%|*}"
    cmd="${p##*|}"

    if [[ "$path_norm" == "$dir"* ]]; then
      # 明确写出“检测到变化”字样
      change_msg="检测到变化: ${path}${file} (${action})"

      # 写到 journal
      log "[$dir] $change_msg"

      # 同时写到该项目的 build.log
      {
        echo "$(date '+%Y-%m-%d %H:%M:%S') [$dir] $change_msg"
      } >> "$dir/build.log" 2>&1

      # 触发构建
      start_timer "$dir" "$cmd"
      break
    fi
  done
done