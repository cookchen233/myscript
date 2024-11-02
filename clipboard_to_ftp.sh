#!/bin/bash

dir="$HOME/Notebook/Baibu"
filename="$dir/Clipboard.txt"
file_stat=""
ftm_cmd_count=4
ftp_cmd_n=0
i=0
while  true; do
    if [[ $file_stat == "" ]]; then
        file_stat=$(stat "$filename")
    fi
    file_stat2=$(stat "$filename")
    ((i++))
    if [[ $? -eq 0 && "$file_stat" != "$file_stat2" ]]; then
        file_stat=$file_stat2
        lftp "ftp-in":"GjYN39%T0e@tL7K$"@192.168.199.213:21 <<EOF
        cd chenwenhao_ftp/Baibu
        put ~/Notebook/Baibu/Clipboard.txt
        quit
EOF
        ((ftp_cmd_n++))
        if [[ $ftp_cmd_n -ge $ftm_cmd_count ]]; then
            ftp_cmd_n=0
            i=0
            osascript -e 'display notification "Upload clipboard to Ubuntu successfully ✅" with title "Clipboard"'
        fi
    fi
    sleep 0.1
done