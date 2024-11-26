#!/bin/bash
# 检查参数数量
if [ "$#" -lt 3 ]; then
    echo "Usage: genmenu <path> <menu_name> <menu_pid>"
    exit 1
fi

MENU_PATH=$1  # 改用 MENU_PATH 而不是 PATH
MENU_NAME=$2
MENU_PID=$3
TOKEN="6Jy31ooWgChbYPDMXKoBxll7UefRt8sTE09xVY8gY6A="
HOST="http://localhost:5174"

# Edge cookie 文件路径 (MacOS)
COOKIE_FILE="$HOME/Library/Application Support/Microsoft Edge/Default/Cookies"

# 使用sqlite3读取cookie (需要先安装sqlite3)
# 注意：Edge在运行时会锁定cookie文件，所以需要先复制一份
TMP_COOKIE_FILE="/tmp/edge_cookies_tmp"
cp "$COOKIE_FILE" "$TMP_COOKIE_FILE"
# 读取指定域名的cookie
COOKIE_VALUE=$(sqlite3 "$TMP_COOKIE_FILE" "SELECT name, value FROM cookies WHERE host_key LIKE '%localhost%' AND name IN ('PHPSESSID', 'think_lang');" | tr '\n' ';')

# 清理临时文件
rm "$TMP_COOKIE_FILE"

# 构建cookie字符串
COOKIE_STRING=$(echo $COOKIE_VALUE | sed 's/|/=/g' | tr ';' ' ' | sed 's/ $//')

# 构建JSON数据
if [ "$MENU_PID" -eq 0 ]; then
    # 顶级菜单
    JSON="{\"menu_pid\":0,\"menu_name\":\"$MENU_NAME\",\"icon\":\"\",\"path\":\"$MENU_PATH\",\"sort\":50,\"status\":1,\"is_show\":1}"
else
    # 子菜单
    JSON="{\"menu_pid\":$MENU_PID,\"menu_name\":\"$MENU_NAME\",\"icon\":\"\",\"path\":\"$MENU_PATH\",\"sort\":50,\"status\":1,\"is_show\":1}"
fi

# 发送请求
curl "$HOST/admin/menus/edit" \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Content-Type: application/json' \
  -H "Cookie: $COOKIE_STRING" \
  -H "admin-token: $TOKEN" \
  -H 'site-id: 0' \
  --data-raw "$JSON"

echo -e "\n创建菜单完成: $MENU_NAME"