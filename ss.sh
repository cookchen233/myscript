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
    # 日志文件路径（无论成功失败都保留）
    log_file="$HOME/Coding/ss_log_$(date +%Y%m%d_%H%M%S).txt"
    status_file="$HOME/Coding/ss_status.txt"
    rm -f "$status_file"  # 只清理状态文件，日志文件保留

    # 立即显示开始执行的通知
    osascript <<EOF
    display notification "Starting build and deploy" with title "myscript" subtitle "⏳ ss in progress" sound name "Frog"
EOF

    # 直接在当前 shell 中执行命令，捕获完整输出
    (
        ss "$1" > "$log_file" 2>&1 && echo 0 > "$status_file" || echo 1 > "$status_file"
    )

    # 检查状态的函数
    check_status() {
        for i in {1..10}; do  # 最多等待10秒
            if [ -f "$status_file" ]; then
                local status=$(cat "$status_file")
                rm -f "$status_file"  # 清理状态文件
                return "$status"
            fi
            sleep 1
        done
        # 如果超时，记录到日志并返回失败
        echo "Timeout: ss did not complete within 10 seconds" >> "$log_file"
        return 1
    }

    # 检查执行结果并显示通知
    check_status
    status=$?
    if [ "$status" -eq 0 ]; then
        osascript <<EOF
        display notification "Build and deploy completed. Log: $log_file" with title "myscript" subtitle "✅ ss complete" sound name "Frog"
EOF
        exit 0
    else
        # 读取错误信息的第一行作为简要提示
        local error_msg
        if [ -f "$log_file" ]; then
            error_msg=$(head -n 1 "$log_file")
        else
            error_msg="Unknown error occurred"
        fi
        osascript <<EOF
        display notification "Build or deploy failed: $error_msg. Log: $log_file" with title "myscript" subtitle "❗️ ss failed" sound name "Frog"
EOF
        open -a TextEdit "$log_file"  # 失败时使用 TextEdit 打开日志
        exit 1
    fi
}