#!/bin/zsh

# Do something on login

# stock monitor
# nohup ~/go/bin/monitor 1 >/dev/null 2>&1 &

# refresh office ip
# nohup ~/Coding/myscript/while_write.sh 1 >/dev/null 2>&1 &

# listen clipboard and upload clipboard to ubuntu
# nohup ~/Coding/myscript/clipboard_to_ftp.sh 1 > /dev/null 2>&1 &

# listen to a server to play error sound for receiving vitual ubuntu server
nohup python ~/Coding/myscript/play_error_sound.py 1 >/dev/null 2>&1 &

# 自动推送仓库
nohup python ~/Coding/myscript/notebook_git_listen.py 1 >/dev/null 2>&1 &
