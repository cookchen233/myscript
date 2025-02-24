#!/bin/bash

# 获取 vite.config.ts 中的 base 路径
bbpath() {
    if [ ! -f vite.config.ts ]; then
        echo "vite.config.ts not found" >&2
        return 1
    fi
    local path
    path=$(/usr/bin/grep -E '^\s*base:' vite.config.ts | /usr/bin/sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/")
    if [[ -z "$path" ]]; then
        echo "Warning: base not found in vite.config.ts, using default '/'" >&2
        path="/"
    fi
    echo "$path"
}

# 构建并部署到远程服务器
bb() {
    local remote="${1:-root@lc.server.host:/www/wwwroot/www.13012345822.com/public/}"
    if ! pnpm build:h5; then
        echo "pnpm build:h5 failed" >&2
        return 1
    fi
    local base_path=$(bbpath) || return 1
    if ! rsync -avzuP ./dist/build/h5/* "${remote}/${base_path}/"; then
        echo "rsync failed" >&2
        return 1
    fi
}

# 特定远程地址的 bb 变体
bbyif() {
    bb "root@lc.server.host:/www/wwwroot/www.yifanglvyou.com/public"
}

# 根据项目类型执行构建和部署
ss() {
    if [ -f "vite.config.ts" ]; then
        if ! bb; then
            echo "bb failed" >&2
            return 1
        fi
    elif [ -f "vite.config.js" ]; then
        if ! git fetch -p origin; then
            echo "Git fetch failed" >&2
            return 1
        fi
        if ! git rebase origin/master; then
            echo "Git rebase failed" >&2
            return 1
        fi
        if ! yarn build; then
            echo "Yarn build failed" >&2
            return 1
        fi
        if ! ~/Coding/myscript/sy/syp.sh master all; then
            echo "syp.sh failed" >&2
            return 1
        fi
    else
        if ! ~/Coding/myscript/sy/syp.sh master; then
            echo "syp.sh failed" >&2
            return 1
        fi
    fi
}

# 配合快捷键并显示通知
ssn() {
    local date_folder="$HOME/Coding/logs/$(date +%Y%m%d)"
    mkdir -p "$date_folder"

    local log_file="$date_folder/ss_log_$(date +%Y%m%d_%H%M%S).log"
    local status_file="$HOME/Coding/ss_status.txt"
    rm -f "$status_file"

    # 开始执行通知
    osascript <<EOF
    display notification "Starting build and deploy" with title "myscript" subtitle "⏳ ss in progress" sound name "Glass"
EOF

    # 执行命令并记录日志
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deploy" > "$log_file"
    if ss "$1" >> "$log_file" 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy succeeded" >> "$log_file"
        # 成功通知
        osascript <<EOF
        display notification "Build and deploy completed. Log: $log_file" with title "myscript" subtitle "✅ ss complete" sound name "Hero"
EOF
        exit 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy failed" >> "$log_file"
        # 读取错误信息
        local error_msg
        error_msg=$(grep -v "^\[" "$log_file" | head -n 1)
        [ -z "$error_msg" ] && error_msg="Unknown error occurred"
        # 失败通知
        osascript <<EOF
        display notification "Build or deploy failed: $error_msg. Log: $log_file" with title "myscript" subtitle "❗️ ss failed" sound name "Sosumi"
EOF
        open -a "Console" "$log_file"
        exit 1
    fi
}
