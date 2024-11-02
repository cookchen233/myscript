#!/bin/zsh

open -a 'IntelliJ IDEA.app'
~/Coding/myscript/connect_to_vpn.sh 1

if [[ $? == 0 ]];then
    osascript -e '
    tell application "IntelliJ IDEA"
        reopen
	    activate
	    tell application "System Events" to key code 4 using {command down, shift down}
    end tell'
    sleep 60
#     /opt/homebrew/bin/lftp bbys-ftp:ftp888@192.168.199.61:8821 <<EOF
# glob -a rm -rf pub-files/chenwenhao_ftp/bbys/*
# quit
# EOF
    /opt/homebrew/bin/lftp "ftp-in":"GjYN39%T0e@tL7K$"@192.168.199.213:21 <<EOF
glob -a rm -rf chenwenhao_ftp/bbys/*
quit
EOF
    echo 'delete successfully'
    
else
    echo "fail"
fi
