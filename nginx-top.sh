#!/bin/bash

# 脚本用途：分析nginx日志，统计最近10分钟访问量前20的地址
# 依赖：rg (ripgrep, invoked as 'command rg'), awk, sort, date, find
# 日志格式：标准nginx日志格式
# 使用示例：./nginx_log_analyzer.sh [log_dir] [time_range] [top_n] [--test-date "YYYY-MM-DD HH:MM:SS"]
# 示例：./nginx_log_analyzer.sh /opt/homebrew/var/log/nginx 10 20 --test-date "2024-12-18 07:17:32"

# 默认参数
LOG_DIR="${1:-/opt/homebrew/var/log/nginx}"
TIME_RANGE="${2:-10}"  # 分钟
TOP_N="${3:-20}"       # 前N条记录
TEST_DATE="${4}"       # 可选：测试用的起始时间

# 检查依赖
for cmd in rg awk sort date find; do
    if [ "$cmd" = "rg" ]; then
        if ! command rg --version &>/dev/null; then
            echo "错误：需要安装 ripgrep (rg)"
            exit 1
        fi
    elif ! command -v "$cmd" &>/dev/null; then
        echo "错误：需要安装 $cmd"
        exit 1
    fi
done

# 设置本地化以避免编码问题
export LC_ALL=C
export LANG=C

# 获取时间范围（BSD-compatible）
if [ -n "$TEST_DATE" ]; then
    CURRENT_TIME=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TEST_DATE" "+%s" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "错误：无效的测试时间格式，请使用 'YYYY-MM-DD HH:MM:SS'，例如 '2024-12-18 07:17:32'"
        exit 1
    fi
else
    CURRENT_TIME=$(date "+%s")
fi
PAST_TIME=$((CURRENT_TIME - TIME_RANGE * 60))
CURRENT_TIME_STR=$(date -j -f "%s" "${CURRENT_TIME}" "+%d/%b/%Y:%H:%M:%S" 2>/dev/null)
PAST_TIME_STR=$(date -j -f "%s" "${PAST_TIME}" "+%d/%b/%Y:%H:%M:%S" 2>/dev/null)

# 生成时间范围的正则表达式（精确到分钟）
TIME_REGEX=$(seq -f "${PAST_TIME_STR:0:11}:%02.0f" 0 $TIME_RANGE | paste -sd '|' -)
# 调试：输出时间范围和正则
# echo "Debug: Analyzing logs from $PAST_TIME_STR to $CURRENT_TIME_STR"
# echo "Debug: Time regex: $TIME_REGEX"

# 临时文件
TEMP_FILE=$(mktemp)
FINAL_FILE=$(mktemp)
trap 'rm -f "${TEMP_FILE}" "${FINAL_FILE}"' EXIT

# 处理日志文件
find "${LOG_DIR}" -type f \( -name "access.log" -o -name "access.log.*.gz" \) -print0 | while IFS= read -r -d '' log_file; do
    domain=$(basename "${log_file}" | sed 's/\.access\.log.*//')
    # 调试：输出正在处理的文件
    # echo "Debug: Processing $log_file (domain: $domain)"
    if [[ "${log_file}" == *.gz ]]; then
        zcat "${log_file}" | command rg --no-filename --text "^[0-9.]+.*\[(${TIME_REGEX}).*\].*\"(GET|POST) [^ \"]+\sHTTP" | awk -v domain="${domain}" '
        {
            time_start = index($0, "[") + 1
            time_end = index($0, "]")
            time_str = substr($0, time_start, time_end - time_start)
            if ($0 ~ /"(GET|POST) [^ \"]+/) {
                split($0, arr, "\"")
                split(arr[2], req, " ")
                url = req[2]
                if (url ~ /\?/) {
                    split(url, url_arr, "?")
                    url = url_arr[1]
                }
                if (time_str && url) {
                    print domain "\t" url "\t" time_str > "/tmp/temp_output.txt"
                }
            }
        }' 
    else
        command rg --no-filename --text "^[0-9.]+.*\[(${TIME_REGEX}).*\].*\"(GET|POST) [^ \"]+\sHTTP" "${log_file}" | awk -v domain="${domain}" '
        {
            time_start = index($0, "[") + 1
            time_end = index($0, "]")
            time_str = substr($0, time_start, time_end - time_start)
            if ($0 ~ /"(GET|POST) [^ \"]+/) {
                split($0, arr, "\"")
                split(arr[2], req, " ")
                url = req[2]
                if (url ~ /\?/) {
                    split(url, url_arr, "?")
                    url = url_arr[1]
                }
                if (time_str && url) {
                    print domain "\t" url "\t" time_str > "/tmp/temp_output.txt"
                }
            }
        }'
    fi
done

# 检查临时文件是否为空
if [ ! -s "/tmp/temp_output.txt" ]; then
    echo "警告：没有找到符合时间范围的日志记录（${PAST_TIME_STR} 到 ${CURRENT_TIME_STR}）"
    if [ -z "$TEST_DATE" ]; then
        echo "提示：您的日志可能较旧，请使用 --test-date 指定分析时间，例如："
        echo "  $0 $LOG_DIR $TIME_RANGE $TOP_N --test-date \"2024-12-18 07:17:32\""
    fi
    # 调试：输出临时文件内容
    # echo "Debug: Temporary file contents:"
    # cat "/tmp/temp_output.txt"
    exit 0
fi

# 统计并排序
awk '
BEGIN {
    # 调试：初始化
    # print "Debug: Starting final awk processing"
}
{
    domain = $1
    url = $2
    time_str = $3
    for (i=4; i<=NF; i++) time_str = time_str " " $i
    key = domain "\t" url
    count[key]++
    if (latest_time[key] == "" || time_str > latest_time[key]) {
        latest_time[key] = time_str
    }
}
END {
    # 调试：输出统计结果
    # for (key in count) {
    #     print "Debug: Key: " key " Count: " count[key] " Latest Time: " latest_time[key]
    # }
    if (length(count) == 0) {
        print "警告：没有符合时间范围的记录可统计"
        exit 0
    }
    # 仅将数据写入最终文件，不包括表头
    for (key in count) {
        split(key, arr, "\t")
        printf "%-30s %-50s %-10d %-20s\n", arr[1], arr[2], count[key], latest_time[key] > "'"${FINAL_FILE}"'"
    }
}' "/tmp/temp_output.txt"

# 排序并输出
if [ -s "${FINAL_FILE}" ]; then
    # 打印表头
    printf "%-30s %-50s %-10s %-20s\n" "Domain" "URL" "Count" "Latest Time"
    printf "%-30s %-50s %-10s %-20s\n" "------" "---" "-----" "-----------"
    # 排序数据并输出
    sort -k3 -nr "${FINAL_FILE}" | head -n "${TOP_N}"
else
    echo "警告：没有生成最终输出，可能由于处理错误"
fi