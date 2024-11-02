#!/bin/bash

exec_script() {
    echo "nohup \"$1\" \"$2\" \"$3\" 1 > /dev/null 2>&1 &" >/tmp/tmp.sh
    chmod +x /tmp/tmp.sh
    open -a 'iTerm.app' /tmp/tmp.sh
}
# 识别为设备号后打开所有相关页面

#set -- "100013"

device_id=$(echo "$1" | tr '[:lower:]' '[:upper:]')
echo "$device_id"
#$(mysql --user="root" --database="mydata" --execute="insert into log(title,content)values('打开项目页', '$device_id')" -s -N)
#device_id=$(mysql --user="root" --database="baibuyinshe" --execute="select device_id from tp_device_install_reg where device_id='$device_id' limit 1" -s -N)
#if [[ "$device_id" == "" ]]; then
    # exit 1
# fi

urls=(
    # 市场部工资汇总
    "https://wx.bbys.cn/admin/dig_developer_score/.html?admin_nav=dig_developer_score"
    # 点位开发绩效明细
    "https://wx.bbys.cn/admin/dig_location/.html?admin_nav=dig_location&device_id=900001"
    # 点位收入报表
    # "https://wx.bbys.cn/admin/device_location_reg/get_device_income.html?admin_nav=12&device_id=900001"
    # 故障列表
    "https://wx.bbys.cn/admin/terminal_device_error/index.html?device_id=900001"
    # 设备列表
    "https://wx.bbys.cn/admin/terminal_device/?admin_nav=1&a.device_id=900001"
    # 打印机列表
    "https://wx.bbys.cn/admin/printer_device/index?device_id=900001&x=1"
    # 订单列表
    # "https://wx.bbys.cn/Mobile/admin/orders/?device_id=900001"
    "https://wx.bbys.cn/admin/order?admin_nav=order&device_id=900001"
)

get_qrcode_url="https://wx.bbys.cn/mobile/api/get_mp_qrcode?printer_id=900001"
show_qrcode_url="https://wx.bbys.cn/admin/ajax/get_qrcode?data="
urls_str="${urls[*]}"
if [[ "$device_id" == "900001"
 || $device_id == "100013" 
 || $device_id == "A120031" 
 || $device_id == "100012" 
 || $device_id == "D120032" 
 || $device_id == "D120033" 
 || $device_id == "661201" 
 || $device_id == "900001" 
 || $device_id == "D120031" 
 || $device_id == "075501" 
 || $device_id == "077101" 
 || $device_id == "600004" 
 || $device_id == "D600004" 
 ]]; then
    urls_str=$(echo "$urls_str" | sed -E -e 's/\/wx.bbys.cn/\/wx-dev.bbys.cn/g')
    get_qrcode_url=$(echo "$get_qrcode_url" | sed -E -e 's/\/wx.bbys.cn/\/wx-dev.bbys.cn/g')
    show_qrcode_url=$(echo "$show_qrcode_url" | sed -E -e 's/\/wx.bbys.cn/\/wx-dev.bbys.cn/g')
fi
urls_str=$(echo "$urls_str" | sed -E -e "s/device_id=[^& ]*/device_id=$device_id/g")

get_qrcode_url=$(echo "$get_qrcode_url" | sed -E -e "s/printer_id=[^& ]*/printer_id=$device_id/g")
exec_script ~/Coding/myscript/open-device-qrcode.sh "$get_qrcode_url" "$show_qrcode_url"

# 新建浏览器独立窗口, 5分钟后自动关闭
osascript <<OSA
tell application "Google Chrome"
  set chromeWindow to make new window
  --activate chromeWindow
  set AppleScript's text item delimiters to " "
  set urls to every text item of "$urls_str"
  repeat with url in urls
    --tell chromeWindow to make new tab with properties {URL:url}
    open location url
  end repeat
end tell
delay 3600
tell application "Google Chrome"
    close chromeWindow
end tell
OSA




