#!/bin/zsh

~/Coding/myscript/connect_to_vpn.sh 1

filename=~/Notebook/Baibu/Clipboard.txt
text=$(pbpaste)
if [[ $text =~ ^.*#DY-[0-9]+[[:space:]].* ]]; then
echo $text
        pbpaste | sed -E -e 'N;s/.*#(DY-[0-9]+)[[:space:]](.*)/\1: \2/g'  > $filename
else
        pbpaste > $filename
fi

lftp "ftp-in":"GjYN39%T0e@tL7K$"@192.168.199.213:21 <<EOF
        cd chenwenhao_ftp/Baibu
        put $filename
        quit
EOF
osascript <<ost
do shell script "
sleep 1
osascript -e '
display notification \"Upload clipboard to Ubuntu successfully ✅\" with title \"Clipboard\" 
'
~/Coding/myscript/auto_login_rdp.sh &
osascript -e '
tell application \"System Events\" to keystroke \"t\" using {command down}
'
"
ost
