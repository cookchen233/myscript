#!/usr/bin/env zsh

# -----------------------------
# 函数：查询指定表的数据
# 用法示例：
#   query 1                   # ...lc_member WHERE member_id(primary key)=1 AND site_id=20
#   query name=xx                   # lc_member WHERE name="xx" AND site_id=20 ORDER BY member_id DESC LIMIT 10
#   query es 123               # lc_ec_shop WHERE id=123 AND site_id=20
#   query es name=xx            # lc_ec_shop WHERE name='xx' AND site_id=20 ORDER BY id DESC LIMIT 10
#   query es name=xx id asc          # lc_ec_shop WHERE name='xx' AND site_id=20 ORDER BY id ASC LIMIT 10
#   query es name=xx id asc limit 20          # lc_ec_shop WHERE name='xx' AND site_id=20 ORDER BY id ASC LIMIT 20
#   query es j eo es.id=eo.shop_id           # lc_ec_shop JOIN lc_ec_order on lc_ec_order.shop_id=lc_ec_shop.id WHERE lc_ec_shop.site_id=20
# -----------------------------

DB_HOST="118.25.213.19"
DB_NAME="api_13012345822"
DB_USER="waynechen"
DB_PASSWORD="Cc@123456"

: ${SITE_ID:=20}

TABLE_ALIAS=(
    "m:lc_member"
    "mt:lc_member_token"
    "mw:lc_member_weixin"
    "eo:lc_ec_order"
    "es:lc_ec_shop"
    "it:lc_insale_team"
    "itm:lc_insale_team_member"
    "ic:lc_insale_commission"
    "tf:lc_insale_team_flow"
    "tc:lc_insale_team_change"
    "tr:lc_insale_team_rate"
    "sa:lc_insale_salary"
    "sl:lc_insale_salary_log"
)

get_short_columns() {
    local tbl="$1"
    local cols=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '$DB_NAME'
          AND TABLE_NAME = '$tbl'
          AND (
            COLUMN_NAME = 'id'
            OR COLUMN_NAME = 'create_time'
            OR COLUMN_NAME LIKE '%_name'
            OR COLUMN_NAME LIKE '%_title'
            OR COLUMN_NAME = 'name'
            OR COLUMN_NAME = 'title'
            OR DATA_TYPE IN ('int', 'tinyint', 'smallint', 'mediumint', 'bigint', 'float', 'double', 'decimal')
            OR (DATA_TYPE = 'varchar' AND CHARACTER_MAXIMUM_LENGTH <= 50)
          )
        ORDER BY ORDINAL_POSITION;" 2>/dev/null
    )
    [ -z "$cols" ] && echo "id" || echo "$cols" | tr '\n' ',' | sed 's/,$//'
}

query() {
    local table="lc_member"
    local condition=""
    local join=""
    local order_by=""
    local limit="LIMIT 10"
    local verbose=1
    local fields=""
    local nowrap=1
    local primary_key="id"
    local main_alias=""

    while [[ "$1" =~ ^- ]]; do
        case "$1" in
            -v) verbose=1; shift;;
            -n) nowrap=1; shift;;
            *) echo "未知选项: $1"; return 1;;
        esac
    done

    if [ -n "$1" ]; then
        for entry in "${TABLE_ALIAS[@]}"; do
            local alias="${entry%%:*}"
            local full_table="${entry##*:}"
            if [ "$1" = "$alias" ]; then
                table="$full_table"
                main_alias="$alias"
                shift
                break
            fi
        done
        # 如果没有匹配到别名，直接使用输入作为表名
        [ "$table" = "lc_member" ] && table="lc_$1" && shift
    fi

    primary_key=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '$DB_NAME'
          AND TABLE_NAME = '$table'
          AND COLUMN_KEY = 'PRI'
        LIMIT 1;" 2>/dev/null || echo "id"
    )
    [ -z "$primary_key" ] && primary_key="id"

    while [ -n "$1" ]; do
        case "$1" in
            [0-9]*) condition="${primary_key} = '$1'"; shift;;
            *=*)
                local key="${1%%=*}"
                local value="${1#*=}"
                condition="${condition:+$condition AND }${key} = '${value}'"
                shift
                ;;
            j)
                shift
                [ -z "$1" ] && { echo "缺少 JOIN 表名"; return 1; }
                local join_alias="$1"
                local join_table=""
                for entry in "${TABLE_ALIAS[@]}"; do
                    if [ "${entry%%:*}" = "$1" ]; then
                        join_table="${entry##*:}"
                        break
                    fi
                done
                [ -z "$join_table" ] && join_table="lc_$1" # 如果没有匹配到别名，直接使用输入作为表名
                shift
                if [ -n "$1" ] && [[ ! "$1" =~ (asc|desc|limit) ]]; then
                    local join_condition="$1"
                    join_condition="${join_condition//${main_alias}./${table}.}"
                    join_condition="${join_condition//${join_alias}./${join_alias}.}"
                    join="LEFT JOIN ${join_table} ${join_alias} ON ${join_condition}"
                    shift
                else
                    join="LEFT JOIN ${join_table} ${join_alias} ON ${table}.${primary_key} = ${join_alias}.shop_id"
                fi
                ;;
            [a-z]*\ asc) order_by="ORDER BY ${1% asc} ASC"; shift;;
            [a-z]*\ desc) order_by="ORDER BY ${1% desc} DESC"; shift;;
            limit\ [0-9]*) limit="LIMIT ${1#limit }"; shift;;
            *) echo "无效参数: $1"; return 1;;
        esac
    done

    [ -z "$order_by" ] && order_by="ORDER BY ${table}.${primary_key} DESC"

    local site_condition="${table}.site_id = ${SITE_ID}"
    condition="${site_condition}${condition:+ AND $condition}"

    local main_cols
    [ -z "$fields" ] && main_cols=$(get_short_columns "$table") || main_cols="$fields"
    main_cols=$(echo "$main_cols" | awk -F',' -v tbl="$table" '{for(i=1;i<=NF;i++) printf "%s%s.%s", (i>1?",":""), tbl, $i}')

    local select_clause="SELECT ${main_cols}"
    if [ -n "$join" ]; then
        local join_cols=$(get_short_columns "$join_table")
        join_cols=$(echo "$join_cols" | awk -F',' -v alias="$join_alias" '{for(i=1;i<=NF;i++) printf "%s%s.%s", (i>1?",":""), alias, $i}')
        select_clause+=", ${join_cols}"
    fi

    local sql="${select_clause} FROM ${table} ${join} WHERE ${condition} ${order_by} ${limit};"

    if [ "$verbose" -eq 1 ]; then
        echo "Tables: ${table}${join:+ + $join_alias}"
        echo "PK: $primary_key"
        echo "SQL: \n$sql"
    fi

    local result
    result=$(MYSQL_PWD="$DB_PASSWORD" \
        mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>&1)

    if [[ "$result" =~ "ERROR" ]]; then
        echo "查询失败: $result"
    elif [ -z "$result" ]; then
        echo "无记录"
    else
        if [ "$nowrap" -eq 1 ]; then
            tput rmam
            echo "$result"
            tput smam
        else
            echo "$result"
        fi
    fi
}

# 获取数据库中的所有表名（用于补全）
get_all_tables() {
    MYSQL_PWD="$DB_PASSWORD" \
    mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = '$DB_NAME'
    ORDER BY TABLE_NAME;" 2>/dev/null
}

get_table_full_name() {
    local alias="$1"
    for entry in "${TABLE_ALIAS[@]}"; do
        if [[ "${entry%%:*}" == "$alias" ]]; then
            echo "${entry##*:}"
            return
        fi
    done
    echo "$alias"  # 如果没有别名映射，直接返回输入
}

# 主逻辑：直接调用 query
query "$@"

# Zsh 补全与快捷键逻辑
if [[ -n "$ZSH_NAME" ]]; then
    # 延迟加载的字段缓存
    typeset -g -A TABLE_FIELDS
    _cache_table_fields() {
        local -a all_tables
        all_tables=($(get_all_tables))
        for tbl in "${all_tables[@]}"; do
            TABLE_FIELDS[$tbl]=$(get_short_columns "$tbl" | tr ',' ' ')
        done
    }

    # 仅在需要时加载缓存
    _ensure_table_fields() {
        if [[ -z "${TABLE_FIELDS[lc_member]}" ]]; then
            _cache_table_fields
        fi
    }

    # 解析上下文中的表名和别名
    _get_context_tables() {
        local -a tables aliases
        local buffer="$1"
        tables=()
        aliases=()

        if [[ "$buffer" =~ "query ([^ ]+)" ]]; then
            tables+=("${match[1]}")
            aliases+=("")
        fi

        while [[ "$buffer" =~ "j ([^ ]+)( .*)?$" ]]; do
            tables+=("${match[1]}")
            aliases+=("${match[1]}")
            buffer="${match[2]}"
        done

        echo "${tables[*]}|${aliases[*]}"
    }

    # 标准补全函数（Tab 触发）
    _query() {
        _ensure_table_fields
        local curcontext="$curcontext" state line
        typeset -A opt_args

        local -a all_tables
        all_tables=($(get_all_tables))

        _arguments -C \
            '1:表名:->tables' \
            '*:参数:->params' && return 0

        case "$state" in
            tables)
                _describe -t tables "表名" all_tables && return 0
                ;;
            params)
                local -a options context_tables context_aliases
                local context=$(_get_context_tables "$BUFFER")
                context_tables=("${(@s/|/)context}[1]")
                context_tables=("${(@s/ /)context_tables}")
                context_aliases=("${(@s/|/)context}[2]")
                context_aliases=("${(@s/ /)context_aliases}")

                case "${words[$CURRENT-1]}" in
                    j)
                        options=("${all_tables[@]/%/:JOIN 表}")
                        ;;
                    limit)
                        options=("10" "20" "50" "100")
                        ;;
                    *=*)
                        local -a fields
                        for i in {1..${#context_tables}}; do
                            local tbl="${context_tables[$i]}"
                            local alias="${context_aliases[$i]:-$tbl}"
                            local tbl_fields=(${(s: :)TABLE_FIELDS[$tbl]})
                            for f in "${tbl_fields[@]}"; do
                                fields+=("${alias}.${f}")
                            done
                        done
                        options=("${fields[@]}")
                        ;;
                    *)
                        options=(
                            "j:加入 JOIN 表"
                            "limit:限制结果数量"
                        )
                        local -a fields
                        for i in {1..${#context_tables}}; do
                            local tbl="${context_tables[$i]}"
                            local alias="${context_aliases[$i]:-$tbl}"
                            local tbl_fields=(${(s: :)TABLE_FIELDS[$tbl]})
                            for f in "${tbl_fields[@]}"; do
                                options+=("${alias}.${f}=:按 ${f} 字段查询")
                                options+=("${alias}.${f} asc:按 ${f} 升序排序")
                                options+=("${alias}.${f} desc:按 ${f} 降序排序")
                            done
                        done
                        ;;
                esac
                _describe -t params "参数" options && return 0
                ;;
        esac
    }

    # 注册 Tab 补全
    compdef _query query

    # 空格触发 fzf 补全
    _query_space() {
        local buffer="$LBUFFER"
        if [[ "$buffer" == "query" ]]; then
            if (( ${+commands[fzf]} )); then
                local selected
                selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border --query="")
                if [[ -n "$selected" ]]; then
                    LBUFFER="query $selected"
                    zle reset-prompt
                fi
            else
                zle self-insert
                zle expand-or-complete
            fi
        elif [[ "$buffer" =~ "query[ ]+[^ ]+[ ].*j$" ]]; then
            if (( ${+commands[fzf]} )); then
                local selected
                selected=$(get_all_tables | fzf --prompt="选择 JOIN 表名 > " --height=40% --border --query="")
                if [[ -n "$selected" ]]; then
                    LBUFFER="$buffer $selected"
                    zle reset-prompt
                fi
            else
                zle self-insert
                zle expand-or-complete
            fi
        else
            zle self-insert
        fi
    }

    # 创建并绑定小部件到空格键
    zle -N _query_space
    bindkey " " _query_space

    # Option+T 触发 fzf
    if (( ${+commands[fzf]} )); then
        _query_fzf() {
            local buffer="$LBUFFER"
            if (( ${+commands[fzf]} )); then
                local selected
                selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border --query="")
                if [[ -n "$selected" ]]; then
                    if [[ "$buffer" =~ "query[ ]+[^ ]+[ ].*j$" ]]; then
                        LBUFFER="$buffer $selected"
                    elif [[ "$buffer" == "query" ]]; then
                        LBUFFER="query $selected"
                    else
                        LBUFFER="$buffer $selected"
                    fi
                    zle reset-prompt
                fi
            fi
        }
        zle -N _query_fzf
        # 使用多种可能的绑定方式
        bindkey '†' _query_fzf      # Option+T 在某些终端下的输出
        bindkey '\M-t' _query_fzf   # Meta+T
        bindkey '\e[116;3u' _query_fzf  # 某些终端的 Option+T
    fi
fi
