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

get_table_aliases() {
    for entry in "${TABLE_ALIAS[@]}"; do
        echo "${entry%%:*}"
    done
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

# Zsh 补全与空格触发逻辑
if [[ -n "$ZSH_NAME" ]]; then
    # 标准补全函数（Tab 触发）
    _query() {
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
                local -a options
                local selected_table="${words[2]}"
                if [[ -n "$selected_table" && " ${all_tables[*]} " =~ " $selected_table " ]]; then
                    local fields=($(get_short_columns "$selected_table" | tr ',' '\n'))
                fi

                case "${words[$CURRENT-1]}" in
                    j)
                        options=("${all_tables[@]/%/:JOIN 表}")
                        ;;
                    limit)
                        options=("10" "20" "50" "100")
                        ;;
                    *=*)
                        if [[ -n "${fields[*]}" ]]; then
                            options=("${fields[@]}")
                        else
                            options=("id" "name" "title")
                        fi
                        ;;
                    *)
                        options=(
                            "j:加入 JOIN 表"
                            "limit:限制结果数量"
                        )
                        if [[ -n "${fields[*]}" ]]; then
                            for field in "${fields[@]}"; do
                                options+=("${field}=:按 ${field} 字段查询")
                            done
                            options+=("${fields[@]/%/ asc}:按字段升序排序")
                            options+=("${fields[@]/%/ desc}:按字段降序排序")
                        else
                            options+=(
                                "id=:按 ID 查询"
                                "name=:按名称查询"
                                "id asc:按 ID 升序排序"
                                "id desc:按 ID 降序排序")
                        fi
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
        # 检查是否精确匹配 "query "
        if [[ "$buffer" == "query" ]]; then
            # 如果输入 "query" 后直接按空格，添加空格并触发 fzf
            LBUFFER="query "
            if (( ${+commands[fzf]} )); then
                local selected
                selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border --query="")
                if [[ -n "$selected" ]]; then
                    LBUFFER="query $selected "
                    zle reset-prompt
                fi
            else
                zle expand-or-complete
            fi
        elif [[ "$buffer" == "query " ]]; then
            # 如果已经输入 "query "，直接触发 fzf
            if (( ${+commands[fzf]} )); then
                local selected
                selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border --query="")
                if [[ -n "$selected" ]]; then
                    LBUFFER="query $selected "
                    zle reset-prompt
                fi
            else
                zle expand-or-complete
            fi
        else
            # 其他情况，正常输入空格
            zle self-insert
        fi
    }

    # 创建并绑定小部件到空格键
    zle -N _query_space
    bindkey " " _query_space

    # 可选：Ctrl+T 触发 fzf
    if (( ${+commands[fzf]} )); then
        _query_fzf() {
            local selected
            selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border)
            if [[ -n "$selected" ]]; then
                LBUFFER="query $selected "
                zle reset-prompt
            fi
        }
        zle -N _query_fzf
        bindkey '^R' _query_fzf
    fi
fi
