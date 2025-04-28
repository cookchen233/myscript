#!/bin/bash

# 获取系统总内存（单位：字节）
TOTAL_MEM=$(sysctl -n hw.memsize) || { echo "无法获取系统内存"; exit 1; }
TOTAL_MEM_MB=$((TOTAL_MEM / 1048576))
THRESHOLD_MEM_MB=$((TOTAL_MEM_MB / 2))

echo "系统总内存: ${TOTAL_MEM_MB} MB"
echo "内存阈值: ${THRESHOLD_MEM_MB} MB"

while true; do
    # 查找 IntelliJ IDEA 相关进程（假设安装路径为默认值，可调整）
    IDEA_PIDS=$(ps aux | grep "[i]dea" | grep "/Applications/IntelliJ IDEA.app" | awk '{print $2}')
    
    if [ -z "$IDEA_PIDS" ]; then
        echo "未找到 IntelliJ IDEA 进程"
        sleep 10
        continue
    fi
    
    # 计算内存总和
    TOTAL_IDEA_MEM_KB=0
    for PID in $IDEA_PIDS; do
        IDEA_MEM_KB=$(ps -p "$PID" -o rss= 2>/dev/null | awk '{print $1}')
        if [ -n "$IDEA_MEM_KB" ]; then
            TOTAL_IDEA_MEM_KB=$((TOTAL_IDEA_MEM_KB + IDEA_MEM_KB))
        fi
    done
    
    TOTAL_IDEA_MEM_MB=$((TOTAL_IDEA_MEM_KB / 1024))
    
    echo "IntelliJ IDEA (PIDs: $IDEA_PIDS) 当前总内存占用: ${TOTAL_IDEA_MEM_MB} MB"
    
    if [ "$TOTAL_IDEA_MEM_MB" -gt "$THRESHOLD_MEM_MB" ]; then
        echo "内存占用超过 ${THRESHOLD_MEM_MB} MB，正在尝试优雅关闭 IntelliJ IDEA..."
        
        osascript <<EOF
        display notification "内存占用超过 50% (${THRESHOLD_MEM_MB} MB)" with title "myscript" subtitle "❗️Kill Idea" sound name "Ping"
EOF

        # 使用 osascript 模拟 GUI 关闭
        osascript -e 'tell application "IntelliJ IDEA" to quit' 2>/dev/null
        
        # 等待 10 秒，给用户时间响应退出确认对话框
        # echo "等待 10 秒以完成关闭..."
        # sleep 10
        
        # # 检查进程是否仍在运行
        # if ps -p "$IDEA_PIDS" > /dev/null 2>&1; then
        #     echo "IntelliJ IDEA 未正常退出，正在强制终止进程..."
        #     for PID in $IDEA_PIDS; do
        #         kill -9 "$PID" 2>/dev/null
        #     done
        #     echo "所有相关进程已强制终止"
        # else
        #     echo "IntelliJ IDEA 已正常退出"
        # fi
    else
        echo "内存占用未超过阈值，继续监控..."
    fi
    
    sleep 10
done