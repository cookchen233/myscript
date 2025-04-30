
# 脚本用途：rg封装
# 依赖：fzf bat
# 使用示例：rg <关键词> [-g 搜文件名而非内容] [目录 默认当前]

rg() {
    local query=""
    local dir="."
    local use_glob=0

    # 调试：显示所有参数
    echo "Debug: Raw args: $@" >&2

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g)
                use_glob=1
                shift
                ;;
            *)
                if [[ -z "$query" ]]; then
                    query="$1"
                elif [[ -d "$1" ]]; then
                    dir="$1"
                fi
                shift
                ;;
        esac
    done

    # 管道或重定向时，直接调用 rg
    if [[ -p /dev/stdout || ! -t 1 ]]; then
        command rg --smart-case "$query" "$dir"
        return
    fi

    # 调试输出
    echo "Debug: query=$query, dir=$dir, use_glob=$use_glob" >&2

    if [[ $use_glob -eq 1 ]]; then
        # 文件名搜索
        echo "Debug: Running rg --files --glob \"*$query*\" \"$dir\"" >&2
        command rg --files --glob "*$query*" "$dir" > /tmp/rg_debug.txt
        echo "Debug: Output saved to /tmp/rg_debug.txt" >&2
        cat /tmp/rg_debug.txt >&2
        command rg --files --glob "*$query*" "$dir" | fzf --ansi \
            --preview 'bat --color=always --style=numbers {}' \
            --preview-window 'up,60%,border-bottom' \
            --bind 'enter:become(vim {})'
    else
        # 内容搜索
#         echo "Debug: Running content search for \"$query\" in \"$dir\"" >&2
# command rg --column --line-number --no-heading --color=always --smart-case "$query" "$dir" | fzf --ansi --delimiter : \
#     --preview 'rg --color=always --smart-case --context=5 --line-number "'"$query"'" {1} | bat --color=always --style=plain' \
#     --preview-window 'up,60%,border-bottom' \
#     --bind 'enter:become(vim {1} +{2})'

        echo "Debug: Running content search for \"$query\" in \"$dir\"" >&2
        command rg --column --line-number --no-heading --color=always --smart-case "$query" "$dir" | fzf --ansi --delimiter : \
            --preview 'rg --color=always --smart-case --context=5 --line-number --context-separator="----------------------------------------" "'"$query"'" {1}' \
            --preview-window 'up,60%,border-bottom' \
            --bind 'enter:become(vim {1} +{2})'

    fi
}