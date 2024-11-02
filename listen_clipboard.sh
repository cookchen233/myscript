#!/bin/bash
# 根据剪贴板内容自动完成各种的任务

text=$(pbpaste)
exec_script() {
    echo "nohup \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\" \"$7\" \"$8\" \"$9\" 1 > /dev/null 2>&1 &" | iconv -f GBK -t UTF-8 >/tmp/tmp.sh
    chmod +x /tmp/tmp.sh
    open -a 'iTerm.app' /tmp/tmp.sh
}

text=$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# 以 "/*", "//" 或 "/**"" 开头
if [[ $text =~ ^/\*+.* || $text =~ ^//.* ]]; then
    # 删除可能的注释符号和多余的星号
    cleaned_text=$(echo "$text" | sed 's/^\/\*\*?//')

    # 获取文本的第一行和第二行
    line1=$(echo "$cleaned_text" | head -n 1)
    line2=$(echo "$cleaned_text" | tail -n +2)

    # 使用awk命令解析文本到变量
    cmd_name=$(echo "$line1" | awk -F ' ' '{print $2}')
    args=$(echo "$line1" | awk -F ' ' '{for(i=3;i<=NF;i++) print $i}')
    # 将解析后的参数放入数组中
    arguments=($args "$line2")
    # arguments=("arg1" "arg2" "中文参数")

    if [[ $cmd_name == "generate-php" ]]; then
        # 使用 "${array[@]}" 将数组中的所有元素作为单个参数传递给命令
        # echo "${arguments[@]}"
        exec_script ~/Coding/myphpartisan/run.py "${arguments[@]}"
    else
        echo "failed"
    fi
    exit 0
fi

# parse log
if [[ $text = {\"content\"\:* || $text =~ \[\s[a-z]{3,6}\s\]\s\{\"time\" ]]; then
    open -a 'iTerm.app' ~/Coding/myscript/parse_ali_log_to_json.sh
# parse annotation and open Postman
elif [ "$(echo -e "$text" | sed -n '2s/^[[:space:]]*\*/Starts with asterisk/p')" ]; then
    pbpaste | sed 's/^[[:space:]]*\*//g' | pbcopy && echo 'successfully processed and set the text to clipboard'
    open -a 'Postman.app'
# parse device_id
elif [[ ${#text} -ge 6 && ${#text} -le 8 && $text =~ [0-9]{4,} ]]; then
    exec_script ~/Coding/myscript/open-all-device-url.sh "$text"
# parse unix time
elif [[ ${#text} -eq 10 && $text =~ ^1[567] ]]; then
    open -a 'iTerm.app' ~/Coding/myscript/parse_unix_time.sh
# upload to ubuntu
else
    # exec_script ~/Coding/myscript/clipboard_to_ftp2.sh
fi
