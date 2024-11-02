#!/bin/bash

file_stat=""
dir="/run/user/1000/gvfs/ftp:host=10.8.8.10/chenwenhao_ftp/Baibu"
filename="$dir/Clipboard.txt"
while  true; do
    ls $dir
    file_stat2=$(stat $filename)
    if [[ $? -eq 0 && "$file_stat" != "$file_stat2" ]]; then
        file_stat=$file_stat2
        cp -r $filename ~/Coding/ftptemps/
    fi
    sleep 0.1
done