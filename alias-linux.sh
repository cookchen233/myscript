chpwd(){
    CLICOLOR_FORCE=1 ls -tr
}

if [[ -n $PS1 ]]; then
  alias ls='eza --color=auto --group-directories-first'
  alias ll='eza --long --all --group --icons'
  alias la='eza --all --group-directories-first'
fi

# alias rr="trash-put"
# alias rrr="trash-restore"
# alias rrrr="trash-rm"
# alias rm="echo 'Please use "rr" instead of "rm"';false"

alias adm="cd /www/wwwroot/api.admin.13012345822.com"
alias api="cd /www/wwwroot/api.13012345822.com"
alias www="cd /www/wwwroot"
alias v="vi"