#!/bin/bash

CONFIG_FILE="$HOME/Coding/myscript/sync_config.txt"

# 读取所有源和目标目录
SOURCES=()
TARGETS=()
while IFS= read -r line; do
    if [[ $line =~ ^SOURCE.*= ]]; then
        SOURCES+=("${line#*=}")
    elif [[ $line =~ ^TARGET.*= ]]; then
        TARGETS+=("${line#*=}")
    fi
done <"$CONFIG_FILE"

# 构建rsync排除参数
EXCLUDE_PARAMS=""
FSWATCH_EXCLUDE=""
while IFS= read -r line; do
    if [[ $line == "IGNORE_LIST" ]]; then
        while IFS= read -r ignore; do
            if [[ -n "$ignore" && ! "$ignore" =~ ^#.*$ ]]; then
                EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude '$ignore'"
                FSWATCH_EXCLUDE="$FSWATCH_EXCLUDE -e \".*$ignore\""
            fi
        done
    fi
done <"$CONFIG_FILE"

# 同步所有目录
sync_all() {
    for i in "${!SOURCES[@]}"; do
        local source="${SOURCES[$i]}"
        local target="${TARGETS[$i]}"

        # 确保目标目录存在
        mkdir -p "$target"

        # 构建并执行rsync命令
        # local RSYNC_CMD="rsync -av --delete $EXCLUDE_PARAMS \"$source/\" \"$target/\""
        local RSYNC_CMD="rsync -av $EXCLUDE_PARAMS \"$source/\" \"$target/\""
        echo "同步: $source -> $target"
        eval "$RSYNC_CMD"
    done
}

# 首次同步
echo "执行首次同步..."
sync_all
echo "首次同步完成"

# 监控所有源目录
WATCH_DIRS=""
for source in "${SOURCES[@]}"; do
    WATCH_DIRS="$WATCH_DIRS \"$source\""
done

# 构建fswatch命令
FSWATCH_CMD="fswatch -o $FSWATCH_EXCLUDE $WATCH_DIRS"

# 监控文件变化并同步
echo "开始监控文件变化..."
eval "$FSWATCH_CMD" | while read f; do
    echo "检测到变化，正在同步..."
    sync_all
    echo "同步完成: $(date)"
done
