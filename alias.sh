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
alias sc="cd ~/Coding/myscript"
alias co="cd ~/Coding"
alias dn="cd ~/Downloads"
alias rr="trash"
alias rm="echo 'Please use rr instead of rm';false"
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

alias sslc='ssh root@lc.server.host -t "tmux attach || tmux"'

source ~/Coding/myscript/ss.sh
# uniapp通常有vite.config.ts, 后台管理系统只有vite.config.js

alias lf='function _logwatch() { ssh root@lc.server.host "tail -F $1"; }; _logwatch'
# 带 lnav 的版本
alias lnf='function _logwatch() { ssh root@lc.server.host "tail -F $1" | lnav; }; _logwatch'



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

# 在 按键值
print_keys() {
    local k
    read -sk k
    printf "Key pressed: "
    printf '%d ' "'$k"
    printf '\n'
}

# 按键值2
test_key() {
    local key
    echo "按下要测试的键 (按 Ctrl+C 退出)..."
    while true; do
        read -sk key
        printf "键码: "
        for i in $(printf %s "$key" | od -An -tx1); do
            printf '%s ' "$i"
        done
        printf '\n'
    done
}

: ${site:=20}
source ~/Coding/myscript/mysql_query.sh
source ~/Coding/myscript/clean_orphans.sh
alias dm=delete_member_and_related
alias dmcc=check_and_clean_orphans
alias q=query
qm() {
    [ -n "$1" ] && site="$1"
    site="$site" q m
}

SERVER="root@lc.server.host"
BASE_PATH="/www/wwwroot/api.13012345822.com/runtime"
DOWNLOAD_DIR=~/Downloads
EDITOR="/Applications/Visual Studio Code.app"
get_log() {
    TODAY=$(date +%d); MONTH=$(date +%Y%m);
    /usr/bin/scp ${SERVER}:${BASE_PATH}/$1/${MONTH}${TODAY}.log ${DOWNLOAD_DIR}/ &&
    /usr/bin/open -a "${EDITOR}" ${DOWNLOAD_DIR}/${TODAY}.log
}

apilog() {
    get_log "api/log"
}

conslog() {
    get_log "log"
}

reqlog() {
    get_log "log/request"
}

greqlog() {
    get_log "log/global-request"
}

admlog() {
    get_log "admin/log"
}
