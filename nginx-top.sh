#!/bin/bash

# 脚本用途：分析nginx日志，统计最近N分钟访问量前M的地址
# 依赖：rg (ripgrep), gawk, sort, date, find
# 使用示例：./nginx_log_analyzer.sh [log_dir] [time_range] [top_n] [--test-date "YYYY-MM-DD HH:MM:SS"]

# 默认参数
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" = "Darwin" ]; then
    LOG_DIR="${1:-/opt/homebrew/var/log/nginx}"
elif [ -d "/www" ] && [ -d "/www/wwwlogs" ]; then
    LOG_DIR="${1:-/www/wwwlogs}"
else
    LOG_DIR="${1:-/var/log/nginx}"
fi

# 检查 LOG_DIR 是否存在
if [ ! -d "$LOG_DIR" ]; then
    echo "错误：日志目录 $LOG_DIR 不存在" >&2
    exit 1
fi

TIME_RANGE="${2:-10}"  # 分钟
TOP_N="${3:-20}"       # 前N条记录
TEST_DATE="${4}"       # 可选：测试用的起始时间
DEBUG="${DEBUG:-0}"    # 调试开关，默认关闭

# 检查依赖
for cmd in rg gawk sort date find; do
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

# 获取时间范围
if [ -n "$TEST_DATE" ]; then
    if [ "$OS_TYPE" = "Darwin" ]; then
        CURRENT_TIME=$(date -j -f "%Y-%m-%d %H:%M:%S" "$TEST_DATE" "+%s" 2>/dev/null)
    else
        CURRENT_TIME=$(date --date="$TEST_DATE" "+%s" 2>/dev/null)
    fi
    if [ $? -ne 0 ]; then
        echo "错误：无效的测试时间格式，请使用 'YYYY-MM-DD HH:MM:SS'"
        exit 1
    fi
else
    CURRENT_TIME=$(date "+%s")
fi
PAST_TIME=$((CURRENT_TIME - TIME_RANGE * 60))
if [ "$OS_TYPE" = "Darwin" ]; then
    CURRENT_TIME_STR=$(date -j -f "%s" "${CURRENT_TIME}" "+%d/%b/%Y:%H:%M:%S %z" 2>/dev/null)
    PAST_TIME_STR=$(date -j -f "%s" "${PAST_TIME}" "+%d/%b/%Y:%H:%M:%S %z" 2>/dev/null)
else
    CURRENT_TIME_STR=$(date --date="@${CURRENT_TIME}" "+%d/%b/%Y:%H:%M:%S %z" 2>/dev/null)
    PAST_TIME_STR=$(date --date="@${PAST_TIME}" "+%d/%b/%Y:%H:%M:%S %z" 2>/dev/null)
fi

# 生成日级时间范围
DAY_RANGE=$(( (TIME_RANGE + 1439) / 1440 ))
TIME_REGEX=""
for ((i=0; i<=DAY_RANGE; i++)); do
    DAY_TIME=$((PAST_TIME + i * 86400))
    if [ "$OS_TYPE" = "Darwin" ]; then
        DAY_STR=$(date -j -f "%s" "${DAY_TIME}" "+%d/%b/%Y" 2>/dev/null)
    else
        DAY_STR=$(date --date="@${DAY_TIME}" "+%d/%b/%Y" 2>/dev/null)
    fi
    if [ -n "$TIME_REGEX" ]; then
        TIME_REGEX="${TIME_REGEX}|${DAY_STR}"
    else
        TIME_REGEX="${DAY_STR}"
    fi
done

# 调试输出
if [ "$DEBUG" -eq 1 ]; then
    echo "Debug: Analyzing logs from $PAST_TIME_STR to $CURRENT_TIME_STR"
    echo "Debug: Unix timestamps: PAST_TIME=$PAST_TIME, CURRENT_TIME=$CURRENT_TIME"
    echo "Debug: TIME_REGEX=$TIME_REGEX"
fi

# 临时文件
TEMP_FILE=$(mktemp)
FINAL_FILE=$(mktemp)
trap 'rm -f "${TEMP_FILE}" "${FINAL_FILE}"' EXIT

# 清空临时文件
: > "/tmp/temp_output.txt"

# 处理日志文件
find "${LOG_DIR}" -type f \( -name "*.log" -o -name "*.log.*.gz" \) -print0 | while IFS= read -r -d '' log_file; do
    domain=$(basename "${log_file}" | sed 's/\.access\.log.*//;s/\.log.*//')
    if [ "$DEBUG" -eq 1 ]; then
        echo "Debug: Processing $log_file"
        MATCH_COUNT=$(if [[ "${log_file}" == *.gz ]]; then zcat "${log_file}"; else cat "${log_file}"; fi | command rg --no-filename --text "^[0-9.]+.*\[(${TIME_REGEX}:[0-2][0-9]:[0-5][0-9]:[0-5][0-9] [+-][0-9]{4}).*\].*\"(GET|POST)" | wc -l)
        echo "Debug: Found $MATCH_COUNT matching lines in $log_file"
    fi
    if [[ "${log_file}" == *.gz ]]; then
        zcat "${log_file}" | command rg --no-filename --text "^[0-9.]+.*\[(${TIME_REGEX}:[0-2][0-9]:[0-5][0-9]:[0-5][0-9] [+-][0-9]{4}).*\].*\"(GET|POST)" | gawk -v domain="${domain}" -v past_time="${PAST_TIME}" -v current_time="${CURRENT_TIME}" '
        BEGIN {
            months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3; months["Apr"] = 4
            months["May"] = 5; months["Jun"] = 6; months["Jul"] = 7; months["Aug"] = 8
            months["Sep"] = 9; months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12
        }
        {
            time_start = index($0, "[") + 1
            time_end = index($0, "]")
            time_str = substr($0, time_start, time_end - time_start)
            split(time_str, parts, "[/: ]")
            day = parts[1] + 0
            month = months[parts[2]]
            year = parts[3] + 0
            hour = parts[4] + 0
            minute = parts[5] + 0
            second = parts[6] + 0
            timestamp = mktime(sprintf("%04d %02d %02d %02d %02d %02d", year, month, day, hour, minute, second))
            if (timestamp >= past_time && timestamp <= current_time && timestamp != -1) {
                if ($0 ~ /"(GET|POST) [^"]+/) {
                    split($0, arr, "\"")
                    split(arr[2], req, " ")
                    url = req[2]
                    referer = arr[4]
                    if (url ~ /\?/) {
                        split(url, url_arr, "?")
                        url = url_arr[1]
                    }
                    # 从 http_referer 提取域名
                    domain_name = domain
                    if (referer ~ /^https?:\/\/[^\/]+/) {
                        match(referer, /^https?:\/\/([^\/]+)/)
                        domain_name = substr(referer, RSTART+7, RLENGTH-7)
                        sub(/:[0-9]+$/, "", domain_name) # 移除端口
                    }
                    if (time_str && url && domain_name != "-") {
                        print domain_name "\t" url "\t" time_str
                    }
                }
            }
        }' >> "/tmp/temp_output.txt"
    else
        command rg --no-filename --text "^[0-9.]+.*\[(${TIME_REGEX}:[0-2][0-9]:[0-5][0-9]:[0-5][0-9] [+-][0-9]{4}).*\].*\"(GET|POST)" "${log_file}" | gawk -v domain="${domain}" -v past_time="${PAST_TIME}" -v current_time="${CURRENT_TIME}" '
        BEGIN {
            months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3; months["Apr"] = 4
            months["May"] = 5; months["Jun"] = 6; months["Jul"] = 7; months["Aug"] = 8
            months["Sep"] = 9; months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12
        }
        {
            time_start = index($0, "[") + 1
            time_end = index($0, "]")
            time_str = substr($0, time_start, time_end - time_start)
            split(time_str, parts, "[/: ]")
            day = parts[1] + 0
            month = months[parts[2]]
            year = parts[3] + 0
            hour = parts[4] + 0
            minute = parts[5] + 0
            second = parts[6] + 0
            timestamp = mktime(sprintf("%04d %02d %02d %02d %02d %02d", year, month, day, hour, minute, second))
            if (timestamp >= past_time && timestamp <= current_time && timestamp != -1) {
                if ($0 ~ /"(GET|POST) [^"]+/) {
                    split($0, arr, "\"")
                    split(arr[2], req, " ")
                    url = req[2]
                    referer = arr[4]
                    if (url ~ /\?/) {
                        split(url, url_arr, "?")
                        url = url_arr[1]
                    }
                    # 从 http_referer 提取域名
                    domain_name = domain
                    if (referer ~ /^https?:\/\/[^\/]+/) {
                        match(referer, /^https?:\/\/([^\/]+)/)
                        domain_name = substr(referer, RSTART+7, RLENGTH-7)
                        sub(/:[0-9]+$/, "", domain_name) # 移除端口
                    }
                    if (time_str && url && domain_name != "-") {
                        print domain_name "\t" url "\t" time_str
                    }
                }
            }
        }' >> "/tmp/temp_output.txt"
    fi
done

# 检查临时文件
if [ ! -s "/tmp/temp_output.txt" ]; then
    echo "警告：没有找到符合时间范围的日志记录（${PAST_TIME_STR} 到 ${CURRENT_TIME_STR}）"
    if [ "$DEBUG" -eq 1 ]; then
        echo "Debug: Sample of temp_output.txt:"
        cat "/tmp/temp_output.txt"
    fi
    exit 0
fi
if [ "$DEBUG" -eq 1 ]; then
    echo "Debug: Sample of temp_output.txt:"
    head -n 5 "/tmp/temp_output.txt"
fi

# 统计并排序
gawk '
BEGIN {
    months["Jan"] = 1; months["Feb"] = 2; months["Mar"] = 3; months["Apr"] = 4
    months["May"] = 5; months["Jun"] = 6; months["Jul"] = 7; months["Aug"] = 8
    months["Sep"] = 9; months["Oct"] = 10; months["Nov"] = 11; months["Dec"] = 12
}
{
    domain = $1
    url = $2
    time_str = $3
    for (i=4; i<=NF; i++) time_str = time_str " " $i
    split(time_str, parts, "[/: ]")
    day = parts[1] + 0
    month = months[parts[2]]
    year = parts[3] + 0
    hour = parts[4] + 0
    minute = parts[5] + 0
    second = parts[6] + 0
    timestamp = mktime(sprintf("%04d %02d %02d %02d %02d %02d", year, month, day, hour, minute, second))
    key = domain "\t" url
    count[key]++
    if (timestamp > latest_timestamp[key] || latest_timestamp[key] == 0) {
        latest_timestamp[key] = timestamp
        latest_time[key] = time_str
    }
}
END {
    if (length(count) == 0) {
        print "警告：没有符合时间范围的记录可统计"
        exit 0
    }
    for (key in count) {
        split(key, arr, "\t")
        printf "%-30s %-50s %-10d %-20s\n", arr[1], arr[2], count[key], latest_time[key] > "'"${FINAL_FILE}"'"
    }
}' "/tmp/temp_output.txt"

# 排序并输出
if [ -s "${FINAL_FILE}" ]; then
    printf "%-30s %-50s %-10s %-20s\n" "Domain" "URL" "Count" "Latest Time"
    printf "%-30s %-50s %-10s %-20s\n" "------" "---" "-----" "-----------"
    sort -k3 -nr "${FINAL_FILE}" | head -n "${TOP_N}"
else
    echo "警告：没有生成最终输出，可能由于处理错误"
fi