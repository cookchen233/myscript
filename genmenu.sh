#!/bin/bash
# 检查参数数量
if [ "$#" -lt 3 ]; then
    echo "Usage: genmenu <path> <menu_name> <menu_pid>"
    exit 1
fi

MENU_PATH=$1  # 改用 MENU_PATH 而不是 PATH
MENU_NAME=$2
MENU_PID=$3
HOST="https://api.13012345822.com"

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

get_token() {
    STORAGE_PATH="$HOME/Library/Application Support/Microsoft Edge/Default/Local Storage/leveldb"
    # Check if the directory exists
    if [ ! -d "$STORAGE_PATH" ]; then
        echo "Edge localStorage directory not found"
        exit 1
    fi
    
    # First find the most recently modified .log file
    LATEST_LOG=$(find "$STORAGE_PATH" -name "*.log" -type f -exec stat -f "%m %N" {} \; | sort -rn | head -n 1 | cut -d' ' -f2-)
    
    if [ -n "$LATEST_LOG" ]; then
        # Try to get token from the latest .log file first
        TOKEN=$(strings "$LATEST_LOG" | \
            grep -A 2 "#_$HOST" | \
            grep -A 1 "admin_token/" | \
            grep -Eo "\"[A-Za-z0-9+/]{40,}={0,2}\"" | \
            sed "s/\"//g" | \
            tail -n 1)
        
        # If we found a token in the .log file, use it
        if [ -n "$TOKEN" ]; then
            echo "$TOKEN"
            return 0
        fi
    fi

    # If no token in .log file, try the most recent .ldb file
    LATEST_LDB=$(find "$STORAGE_PATH" -name "*.ldb" -type f -exec stat -f "%m %N" {} \; | sort -rn | head -n 1 | cut -d' ' -f2-)
    find "$STORAGE_PATH" -name "*.ldb" -type f -exec stat -f "%m %N" {} \; | sort -rn | head -n 1 | cut -d' ' -f2-
    if [ -n "$LATEST_LDB" ]; then
        TOKEN=$(strings "$LATEST_LDB" | \
            grep -A 2 "#_$HOST" | \
            grep -A 1 "admin_token/" | \
            grep -Eo "\"[A-Za-z0-9+/]{40,}={0,2}\"" | \
            sed "s/\"//g" | \
            tail -n 1)
    fi

    if [ -n "$TOKEN" ]; then
        echo "$TOKEN"
        return 0
    else
        echo "Could not extract token value"
        return 1
    fi
}

# 获取token
TOKEN=$(get_token)
if [ $? -ne 0 ]; then
    TOKEN="fOhLRlxQmuJ/+6/3kjMj4v0Bf+3uvhIYRIOMCI3oUWM="
fi

# 发送请求并保存响应
RESPONSE=$(curl -s "$HOST/admin/menus/edit" \
  -H 'accept: application/json, text/plain, */*' \
  -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
  -H 'content-type: application/json' \
  -H 'site-id: 0' \
  -H "Cookie: $COOKIE_STRING" \
  -H "admin-token: $TOKEN" \
  --data-raw "$JSON")

# 检查curl是否成功
if [ $? -ne 0 ]; then
    echo -e "\nfailed: $MENU_NAME - curl error"
    exit 1
fi

# 从响应中提取code
CODE=$(echo $RESPONSE | grep -o '"code":[0-9]*' | cut -d':' -f2)
MSG=$(echo $RESPONSE | grep -o '"msg":"[^"]*"' | cut -d'"' -f4)

if [ "$CODE" != "1" ]; then
    echo -e "\nfailed: $MENU_NAME - $MSG"
    echo "Response: $RESPONSE"
    exit 1
fi

echo -e "\n创建菜单完成: $MENU_NAME"