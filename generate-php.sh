# 给定的文本
text=" // generate-php dto admin/DeviceExwarehouseDto a1 a2 设备的出库申请信息数据对象
line2_content"


# 去除文本两端的空格
text=$(echo "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# 使用正则表达式判断文本的开头
if [[ $text =~ ^/\*+.* ]]; then
    echo "以 /* 或 /** 开头"
elif [[ $text =~ ^//.* ]]; then
    echo "以 // 开头"
else
    echo "其他情况"
fi

# 删除可能的注释符号和多余的星号
cleaned_text=$(echo "$text" | sed 's/^\/\*\*?//')

# 获取文本的第一行和第二行
line1=$(echo "$cleaned_text" | head -n 1)
line2=$(echo "$cleaned_text" | tail -n 1)

# 使用awk命令解析文本到变量
cmd_name=$(echo "$line1" | awk -F ' ' '{print $2}')
args=$(echo "$line1" | awk -F ' ' '{for(i=3;i<=NF;i++) print $i}')

# 将解析后的参数放入数组中
arguments=($args "$line2")

# 输出结果
echo "cmd_name=\"$cmd_name\""
echo "arguments=(" "${arguments[@]}" ")"
