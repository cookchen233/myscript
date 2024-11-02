#!/bin/bash
# 异步获取二维码并打开页面

get_qrcode_url=$(curl -s "$1"| jq -r '.result.url')
show_qrcode_url="$2$get_qrcode_url"
echo "$1","$2"
osascript <<osa
tell application "Google Chrome" to open location "$show_qrcode_url"
osa




