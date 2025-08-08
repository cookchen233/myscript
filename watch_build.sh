#!/bin/bash
# 安装 sudo dnf install -y inotify-tools
set -euo pipefail

export PATH="$(npm bin -g):/usr/local/bin:/usr/bin:/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

WATCH_DIR="/www/wwwroot/wnsafe.com"
BUILD_CMD="npm run build"
DEBOUNCE=2

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

EXCLUDE_PAT='(^|/)\.git($|/)|(^|/)node_modules($|/)|(^|/)dist($|/)|(^|/)build($|/)|(^|/)\.next($|/)|(^|/)\.nuxt($|/)|\.swp$|~$|\.tmp$|\.log$'

cd "$WATCH_DIR"

timer_pid=""

start_timer() {
    if [[ -n "${timer_pid}" ]] && kill -0 "$timer_pid" 2>/dev/null; then
        kill "$timer_pid" 2>/dev/null || true
    fi

    (
        sleep "$DEBOUNCE"
        log "开始构建：$BUILD_CMD"
        $BUILD_CMD
        log "构建完成。"
    ) &
    timer_pid=$!
}

inotifywait -m -r \
    -e close_write,create,delete,move \
    --exclude "$EXCLUDE_PAT" \
    "$WATCH_DIR" 2>/dev/null | while read -r path action file; do
        log "检测到变化: $path$file ($action)"
        start_timer
done