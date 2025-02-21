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

export DB_USER="waynechen"
export DB_PASSWORD="Cc@123456"
dm() {
    if [ -z "$1" ]; then
        echo "请提供会员ID"
        return 1
    fi
    
    member_id=$1
    
    MYSQL_PWD=$DB_PASSWORD mysql -h118.25.213.19 -u$DB_USER api_13012345822 <<EOF
DELETE m, mt, mw, eo, es, it, itm, ic, tf, tc, tr, sa, sl
FROM lc_member m
LEFT JOIN lc_member_token mt ON mt.member_id = '$member_id'
LEFT JOIN lc_member_weixin mw ON mw.member_id = '$member_id'
LEFT JOIN lc_ec_order eo ON eo.member_id = '$member_id'
LEFT JOIN lc_ec_shop es ON es.member_id = '$member_id'
LEFT JOIN lc_insale_team it ON it.member_id = '$member_id'
LEFT JOIN lc_insale_team_member itm ON itm.member_id = '$member_id'
LEFT JOIN lc_insale_commission ic ON ic.member_id = '$member_id'
LEFT JOIN lc_insale_team_flow tf ON tf.member_id = '$member_id'
LEFT JOIN lc_insale_team_change tc ON tc.member_id = '$member_id'
LEFT JOIN lc_insale_team_rate tr ON tr.member_id = '$member_id'
LEFT JOIN lc_insale_salary sa ON sa.member_id = '$member_id'
LEFT JOIN lc_insale_salary_log sl ON sl.member_id = '$member_id'
WHERE (
    m.member_id = '$member_id'
    OR m.username = '$member_id'
    OR m.mobile = '$member_id'
    OR mt.member_id = '$member_id'
    OR mw.member_id = '$member_id'
    OR eo.member_id = '$member_id'
    OR es.member_id = '$member_id'
    OR it.member_id = '$member_id'
    OR itm.member_id = '$member_id'
    OR ic.member_id = '$member_id'
    OR tf.member_id = '$member_id'
    OR tc.member_id = '$member_id'
    OR tr.member_id = '$member_id'
    OR sa.member_id = '$member_id'
    OR sl.member_id = '$member_id'
);
EOF
}

export DB_USER="waynechen"
export DB_PASSWORD="Cc@123456"
check_and_clean_orphans() {
    # 临时存储查询结果
    echo "正在查询孤儿记录..."
    orphans=$(MYSQL_PWD=$DB_PASSWORD mysql -h118.25.213.19 -u$DB_USER api_13012345822 <<EOF
SELECT 
    mt.member_id AS mt_member_id,
    mw.member_id AS mw_member_id,
    eo.member_id AS eo_member_id,
    es.member_id AS es_member_id,
    it.member_id AS it_member_id,
    itm.member_id AS itm_member_id,
    ic.member_id AS ic_member_id,
    tf.member_id AS tf_member_id,
    tc.member_id AS tc_member_id,
    tr.member_id AS tr_member_id,
    sa.member_id AS sa_member_id,
    sl.member_id AS sl_member_id
FROM lc_member m
LEFT JOIN lc_member_token mt ON mt.member_id = m.member_id
LEFT JOIN lc_member_weixin mw ON mw.member_id = m.member_id
LEFT JOIN lc_ec_order eo ON eo.member_id = m.member_id
LEFT JOIN lc_ec_shop es ON es.member_id = m.member_id
LEFT JOIN lc_insale_team it ON it.member_id = m.member_id
LEFT JOIN lc_insale_team_member itm ON itm.member_id = m.member_id
LEFT JOIN lc_insale_commission ic ON ic.member_id = m.member_id
LEFT JOIN lc_insale_team_flow tf ON tf.member_id = m.member_id
LEFT JOIN lc_insale_team_change tc ON tc.member_id = m.member_id
LEFT JOIN lc_insale_team_rate tr ON tr.member_id = m.member_id
LEFT JOIN lc_insale_salary sa ON sa.member_id = m.member_id
LEFT JOIN lc_insale_salary_log sl ON sl.member_id = m.member_id
WHERE m.member_id IS NULL
  AND (mt.member_id IS NOT NULL
    OR mw.member_id IS NOT NULL
    OR eo.member_id IS NOT NULL
    OR es.member_id IS NOT NULL
    OR it.member_id IS NOT NULL
    OR itm.member_id IS NOT NULL
    OR ic.member_id IS NOT NULL
    OR tf.member_id IS NOT NULL
    OR tc.member_id IS NOT NULL
    OR tr.member_id IS NOT NULL
    OR sa.member_id IS NOT NULL
    OR sl.member_id IS NOT NULL);
EOF
)

    echo "原始查询结果："
    echo "$orphans"
    echo "结果长度：${#orphans}"

    # 检查是否有孤儿记录
    if [ -z "$orphans" ]; then
        echo "没有找到孤儿记录。"
        return 0
    fi

    # 显示查询结果
    echo "找到以下孤儿记录："
    echo "$orphans"
    echo

    # 提示用户确认
    while true; do
        read -p "是否删除这些记录？(y/n): " choice
        case $choice in
            [Yy]*)
                # 执行删除
                echo "正在删除孤儿记录..."
                MYSQL_PWD=$DB_PASSWORD mysql -h118.25.213.19 -u$DB_USER api_13012345822 <<EOF
DELETE mt, mw, eo, es, it, itm, ic, tf, tc, tr, sa, sl
FROM lc_member m
LEFT JOIN lc_member_token mt ON mt.member_id = m.member_id
LEFT JOIN lc_member_weixin mw ON mw.member_id = m.member_id
LEFT JOIN lc_ec_order eo ON eo.member_id = m.member_id
LEFT JOIN lc_ec_shop es ON es.member_id = m.member_id
LEFT JOIN lc_insale_team it ON it.member_id = m.member_id
LEFT JOIN lc_insale_team_member itm ON itm.member_id = m.member_id
LEFT JOIN lc_insale_commission ic ON ic.member_id = m.member_id
LEFT JOIN lc_insale_team_flow tf ON tf.member_id = m.member_id
LEFT JOIN lc_insale_team_change tc ON tc.member_id = m.member_id
LEFT JOIN lc_insale_team_rate tr ON tr.member_id = m.member_id
LEFT JOIN lc_insale_salary sa ON sa.member_id = m.member_id
LEFT JOIN lc_insale_salary_log sl ON sl.member_id = m.member_id
WHERE m.member_id IS NULL
  AND (mt.member_id IS NOT NULL
    OR mw.member_id IS NOT NULL
    OR eo.member_id IS NOT NULL
    OR es.member_id IS NOT NULL
    OR it.member_id IS NOT NULL
    OR itm.member_id IS NOT NULL
    OR ic.member_id IS NOT NULL
    OR tf.member_id IS NOT NULL
    OR tc.member_id IS NOT NULL
    OR tr.member_id IS NOT NULL
    OR sa.member_id IS NOT NULL
    OR sl.member_id IS NOT NULL);
EOF
                echo "删除完成。"
                break
                ;;
            [Nn]*)
                echo "取消删除操作。"
                break
                ;;
            *)
                echo "请输入 y 或 n。"
                ;;
        esac
    done
}


apilog() {
    TODAY=$(date +%d); MONTH=$(date +%Y%m); /usr/bin/scp root@118.25.213.19:/www/wwwroot/api.13012345822.com/runtime/api/log/${MONTH}/${TODAY}.log ~/Downloads/ && /usr/bin/open -a '/Applications/Visual Studio Code.app' ~/Downloads/${TODAY}.log
}
consolelog() {
    TODAY=$(date +%d); MONTH=$(date +%Y%m); /usr/bin/scp root@118.25.213.19:/www/wwwroot/api.13012345822.com/runtime/log/${MONTH}/${TODAY}.log ~/Downloads/ && /usr/bin/open -a '/Applications/Visual Studio Code.app' ~/Downloads/${TODAY}.log
}