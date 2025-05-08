#!/bin/bash
# 脚本用途：从远程服务器获取文件并直接在本地编辑器中打开（使用临时文件）
# 依赖：ssh, scp, open, Visual Studio Code, mktemp
# 使用示例：./getfile.sh "root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log"

[ -z "$1" ] && { echo "Usage: $0 \"server:filename\""; exit 1; }
IFS=':' read -r SERVER FILE <<< "$1"
[ -z "$SERVER" ] || [ -z "$FILE" ] && { echo "Error: Invalid format, use \"server:filename\""; exit 1; }
TMP=$(mktemp) || { echo "Error: Failed to create temp file"; exit 1; }
ssh "$SERVER" "[ -f \"$FILE\" ]" || { echo "Error: File $FILE does not exist on $SERVER"; rm -f "$TMP"; exit 1; }
scp "$SERVER:$FILE" "$TMP" || { echo "Error: Failed to download $FILE"; rm -f "$TMP"; exit 1; }
open -a "Visual Studio Code" "$TMP" & # 后台运行，避免阻塞
sleep 1 # 等待 VS Code 加载
rm -f "$TMP"

#!/bin/bash
# 脚本用途：将本地文件使用 scp 上传到远程服务器的指定绝对路径
# 依赖：scp, ssh, basename, dirname
# 使用示例：
#   ./putfile.sh "root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log"
#   ./putfile.sh "root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log" ./mylog.log

[ -z "$1" ] && { echo "Usage: $0 \"server:filename\" [local_file]"; exit 1; }
IFS=':' read -r SERVER REMOTE_FILE <<< "$1"
[ -z "$SERVER" ] || [ -z "$REMOTE_FILE" ] && { echo "Error: Invalid

format, use \"server:filename\""; exit 1; }
LOCAL_FILE="${2:-$(basename "$REMOTE_FILE")}"
[ -f "$LOCAL_FILE" ] || { echo "Error: Local file $LOCAL_FILE does not exist"; exit 1; }
ssh "$SERVER" "[ -d \"$(dirname "$REMOTE_FILE")\" ]" || { echo "Error: Remote directory $(dirname "$REMOTE_FILE") does not exist on $SERVER"; exit 1; }
scp -C "$LOCAL_FILE" "$SERVER:$REMOTE_FILE" || { echo "Error: Failed to upload $LOCAL_FILE to $REMOTE_FILE"; exit 1; }
echo "File $LOCAL_FILE uploaded to $SERVER:$REMOTE_FILE"

# rsync
#!/bin/bash
# 脚本用途：将本地文件使用 rsync 上传到远程服务器的指定绝对路径
# 依赖：rsync, ssh, basename, dirname
# 使用示例：
#   ./putfile.sh "root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log"
#   ./putfile.sh "root@server.lc:/www/wwwroot/api.13012345822.com/runtime/api/log/20250501.log" ./mylog.log

# [ -z "$1" ] && { echo "Usage: $0 \"server:filename\" [local_file]"; exit 1; }
# IFS=':' read -r SERVER REMOTE_FILE <<< "$1"
# [ -z "$SERVER" ] || [ -z "$REMOTE_FILE" ] && { echo "Error: Invalid format, use \"server:filename\""; exit 1; }
# LOCAL_FILE="${2:-$(basename "$REMOTE_FILE")}"
# [ -f "$LOCAL_FILE" ] || { echo "Error: Local file $LOCAL_FILE does not exist"; exit 1; }
# ssh "$SERVER" "[ -d \"$(dirname "$REMOTE_FILE")\" ]" || { echo "Error: Remote directory $(dirname "$REMOTE_FILE") does not exist on $SERVER"; exit 1; }
# rsync -avzuP "$LOCAL_FILE" "$SERVER:$REMOTE_FILE" || { echo "Error: Failed to upload $LOCAL_FILE to $REMOTE_FILE"; exit 1; }
# echo "File $LOCAL_FILE uploaded to $SERVER:$REMOTE_FILE"