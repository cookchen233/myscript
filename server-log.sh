#!/bin/bash

# 脚本用途：从远程服务器下载指定日期的日志文件并在本地编辑器中打开
# 依赖：ssh, scp, date, open, Visual Studio Code (或其他配置的编辑器)
# 使用示例：./script.sh apilog [YYYYMMDD] [-s server:base_path]
#           ./script.sh conslog 20250501
#           ./script.sh reqlog -s user@otherserver:/path 20250501
# ssh root@server.lc "[ -f /www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log ]" && /usr/bin/scp root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log ~/Downloads/ && /usr/bin/open -a "/Applications/Visual Studio Code.app" ~/Downloads/20250501.log

SERVER_DIR="root@server.lc:/www/wwwroot/api.13012345822.com/runtime"
DOWNLOAD_DIR=~/Downloads
EDITOR="/Applications/Visual Studio Code.app"

# 获取日志通用函数
getlog() {
    local SUBDIR="$1"           # 日志子目录（如 api/log）
    local TARGET_DATE="$2"      # 日期，默认为今天
    local SERVER_DIR="$3"       # 服务器地址和路径（如 root@server.lc:/path）
    TARGET_DATE=${TARGET_DATE:-$(date +%Y%m%d)}
    
    # 验证 TARGET_DATE 格式
    if [[ ! $TARGET_DATE =~ ^[0-9]{8}$ ]]; then
        echo "Error: Invalid date format '$TARGET_DATE'. Use YYYYMMDD."
        return 1
    fi

    local MONTH=${TARGET_DATE:0:6}
    local DAY=${TARGET_DATE:6:2}
    local PATH_SUFFIX="${SUBDIR:+/$SUBDIR}" # 子目录前缀，空时为空

    # 提取 SERVER 和 BASE_PATH
    local SERVER="${SERVER_DIR%%:*}" # e.g., root@server.lc
    local BASE_PATH="${SERVER_DIR#*:}" # e.g., /www/wwwroot/api.13012345822.com/runtime
    local REMOTE_PATH="${BASE_PATH}${PATH_SUFFIX}/${MONTH}${DAY}.log"

    # 调试：输出参数和路径
    echo "DEBUG: SUBDIR=$SUBDIR, TARGET_DATE=$TARGET_DATE, SERVER_DIR=$SERVER_DIR"
    echo "Attempting to fetch: ${SERVER}:${REMOTE_PATH}"

    # 检查文件是否存在
    ssh "$SERVER" "[ -f \"$REMOTE_PATH\" ]" || {
        echo "Error: File $REMOTE_PATH does not exist on $SERVER"
        return 1
    }

    # 使用 scp 下载日志并打开
    /usr/bin/scp "${SERVER}:${REMOTE_PATH}" "${DOWNLOAD_DIR}/" &&
    /usr/bin/open -a "${EDITOR}" "${DOWNLOAD_DIR}/${MONTH}${DAY}.log"
}

# 通用选项解析函数
parse_args() {
    local SUBDIR="$1"
    shift # 移除 SUBDIR 参数，处理剩余的命令行参数
    local SERVER_DIR="$SERVER_DIR" # 默认使用全局 SERVER_DIR
    local DATE=""

    # 重置 OPTIND 以确保正确解析
    OPTIND=1

    # 解析选项
    while getopts "s:" opt; do
        case $opt in
            s) SERVER_DIR="$OPTARG" ;; # 使用提供的完整 SERVER_DIR
            *) echo "Usage: $0 [-s server:base_path] [date]"; return 1 ;;
        esac
    done
    shift $((OPTIND-1))

    # 第一个非选项参数作为日期
    [ $# -gt 0 ] && DATE="$1"

    # 调试：输出解析后的参数
    echo "DEBUG: Parsed SUBDIR=$SUBDIR, SERVER_DIR=$SERVER_DIR, DATE=$DATE"

    # 调用 getlog
    getlog "$SUBDIR" "$DATE" "$SERVER_DIR"
}

# 日志命令函数
apilog() {
    parse_args "api/log" "$@"
}

conslog() {
    parse_args "log" "$@"
}

reqlog() {
    parse_args "log/request" "$@"
}

greqlog() {
    parse_args "log/global-request" "$@"
}

admlog() {
    parse_args "admin/log" "$@"
}