refresh_smb() {
    sudo kill -HUP `ps -ax | grep mds | grep -v grep | awk '{print $1}'`
    echo "SMB cache refreshed"
}
chpwd(){
    CLICOLOR_FORCE=1 ls -tr
}

bg_black="\033[40m"
bg_red="\033[41m"
bg_green="\033[42m"
bg_yellow="\033[43m"
bg_blue="\033[44m"
bg_purple="\033[45m"
bg_cyan="\033[46m"
bg_white="\033[47m"
    
fg_black="\033[30m"
fg_red="\033[31m"
fg_green="\033[32m"
fg_yellow="\033[33m"
fg_blue="\033[34m"
fg_purple="\033[35m"
fg_cyan="\033[36m"
fg_white="\033[37m"
    
set_clear="\033[0m"
set_bold="\033[1m"
set_underline="\033[4m"
set_flash="\033[5m"

alias v='open -a /Applications/Visual\ Studio\ Code.app'
alias s="cd ~/Coding/myscript"
alias c="cd ~/Coding"
alias d="cd ~/Downloads"
alias del="trash"
alias vs="networksetup -showpppoestatus Atlantic"
alias vd="networksetup -disconnectpppoeservice 'Atlantic'"
alias vv="~/Coding/myscript/connect_to_vpn.sh"
alias aj="~/Coding/myscript/parse_ali_log_to_json.sh"
alias an="pbpaste | sed 's/^\([^\*]\)/\*\1/g' | pbcopy && echo 'successfully processed and set the text to clipboard' && open -a 'IntelliJ IDEA.app'"
alias na="pbpaste | sed 's/^[[:space:]]*\*//g' | pbcopy && echo 'successfully processed and set the text to clipboard' && open -a 'Postman.app'"
#alias nb="git fetch --all && git fetch -p origin && git checkout origin/main -b"
alias nb="git checkout main -b"
alias dv="~/Coding/myscript/open-all-device-url.sh"

alias gen='~/Coding/myscript/alphagen/main.py'
alias syp='~/Coding/myscript/sy/syp.sh'
alias sy='~/Coding/myscript/sy/sy.sh'
alias genm='~/Coding/myscript/genmenu.sh'
alias py='python3'
alias qr='qrencode -t ANSIUTF8'
alias cc='git checkout -- . && git clean -fd'
alias ss='[ -f "vite.config.js" ] && { yarn build && ~/Coding/myscript/sy/syp.sh master all; } || ~/Coding/myscript/sy/syp.sh master'
alias bb='pnpm build:h5 && rsync -avzuP  /Users/Chen/Coding/bbv2-uniapp/dist/build/h5/*  root@118.25.213.19:/www/wwwroot/www.13012345822.com/public/bbv2/'
alias bb2='pnpm build:h5 && rsync -avzuP  /Users/Chen/Coding/bbv2-uniapp/dist/build/h5/*  root@118.25.213.19:/www/wwwroot/www.yifanglvyou.com/public/bbv2/'
alias ss19='ssh root@118.25.213.19 -t "tmux attach || tmux"'

alias lf='function _logwatch() { ssh root@118.25.213.19 "tail -F $1"; }; _logwatch'
# 带 lnav 的版本
alias lnf='function _logwatch() { ssh root@118.25.213.19 "tail -F $1" | lnav; }; _logwatch'



curlj() {
    /usr/bin/curl -s "$@" | jq -C . 2>/dev/null || /usr/bin/curl -s "$@"
}
alias curl=curlj

function ag() {
    if [[ "$1" == "-l" ]]; then
        command ag -l "${@:2}" | fzf | xargs o
    else
        command ag "$@"
    fi
}

function tal() {
    tail -f /Users/Chen/Coding/myscript/notification-server/main.log | awk '
/^Details:/ {
    printf "\033[31m%s\033[0m\n",$0;
    p=1;
    next
}
p&&/^trace_id:/{p=0}
p {
    printf "\033[36m%s\033[0m\n",$0
}'
}

source ~/Coding/myscript/mysql_query.sh
source ~/Coding/myscript/clean_orphans.sh
alias dm=delete_member_and_related
alias dmcc=check_and_clean_orphans
alias q=query

apilog() {
    TODAY=$(date +%d); MONTH=$(date +%Y%m); /usr/bin/scp root@118.25.213.19:/www/wwwroot/api.13012345822.com/runtime/api/log/${MONTH}/${TODAY}.log ~/Downloads/ && /usr/bin/open -a '/Applications/Visual Studio Code.app' ~/Downloads/${TODAY}.log
}
consolelog() {
    TODAY=$(date +%d); MONTH=$(date +%Y%m); /usr/bin/scp root@118.25.213.19:/www/wwwroot/api.13012345822.com/runtime/log/${MONTH}/${TODAY}.log ~/Downloads/ && /usr/bin/open -a '/Applications/Visual Studio Code.app' ~/Downloads/${TODAY}.log
}