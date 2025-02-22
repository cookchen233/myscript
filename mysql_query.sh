#!/usr/bin/env zsh

# -----------------------------
# 函数：查询指定表的数据
# 用法示例：
#   query 1                   # ...lc_member WHERE member_id(primary key)=1 AND site_id=20
#   query name=xx             # lc_member WHERE name="xx" AND site_id=20 ORDER BY member_id DESC LIMIT 20
#   query es 123              # lc_ec_shop WHERE id=123 AND site_id=20
#   query es name=xx          # lc_ec_shop WHERE name='xx' AND site_id=20 ORDER BY id DESC LIMIT 20
#   query es name=xx id asc   # lc_ec_shop WHERE name='xx' AND site_id=20 ORDER BY id ASC LIMIT 20
#   query es j eo es.id=eo.shop_id  # lc_ec_shop JOIN lc_ec_order on lc_ec_order.shop_id=lc_ec_shop.id
# -----------------------------

DB_HOST="118.25.213.19"
DB_NAME="api_13012345822"
DB_USER="waynechen"
DB_PASSWORD="Cc@123456"

: ${site:=20}

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

# 获取表的简短字段列表（用于查询显示）
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

# 主查询函数
query() {
    local table="lc_member"
    local condition=""
    local join=""
    local order_by=""
    local limit="LIMIT 20"
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

    # 处理表名和别名（确保第一个参数总是表名）
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
        if [ "$table" = "lc_member" ]; then
            table="lc_$1"
            table=${table/lc_lc_/lc_}
            main_alias="$1"
            shift
        fi
        # 处理显式指定的主表别名
        if [ -n "$1" ] && [[ ! "$1" =~ (j|where|limit|desc|asc|=) ]]; then
            main_alias="$1"
            shift
        fi
    fi

    # 如果 main_alias 仍为空，使用表名作为默认别名（去掉 lc_ 前缀）
    [ -z "$main_alias" ] && main_alias="${table#lc_}"

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
                local join_alias=""
                local join_table=""
                for entry in "${TABLE_ALIAS[@]}"; do
                    if [ "${entry%%:*}" = "$1" ]; then
                        join_table="${entry##*:}"
                        join_alias="$1"
                        break
                    fi
                done
                [ -z "$join_table" ] && join_table="lc_$1" && join_table=${join_table/lc_lc_/lc_} && join_alias="$1"
                shift
                if [ -n "$1" ] && [[ ! "$1" =~ (where|limit|desc|asc|=) ]]; then
                    join_alias="$1"
                    shift
                fi
                if [ -n "$1" ] && [[ ! "$1" =~ (where|limit|desc|asc) ]]; then
                    local join_condition="$1"
                    join="LEFT JOIN ${join_table} ${join_alias} ON ${join_condition}"
                    shift
                else
                    join="LEFT JOIN ${join_table} ${join_alias} ON ${main_alias}.${primary_key} = ${join_alias}.shop_id"
                fi
                ;;
            where)
                shift
                if [ -n "$1" ] && [[ ! "$1" =~ (limit|desc|asc) ]]; then
                    condition="${condition:+$condition AND }$1"
                    shift
                fi
                ;;
            [a-z.]*\ asc) order_by="ORDER BY ${1% asc} ASC"; shift;;
            [a-z.]*\ desc) order_by="ORDER BY ${1% desc} DESC"; shift;;
            limit\ [0-9]*) limit="LIMIT ${1#limit }"; shift;;
            *) echo "无效参数: $1"; return 1;;
        esac
    done

    [ -z "$order_by" ] && order_by="ORDER BY ${main_alias}.${primary_key} DESC"

    local site_condition="${main_alias}.site_id = ${site}"
    condition="${site_condition}${condition:+ AND $condition}"

    local main_cols
    [ -z "$fields" ] && main_cols=$(get_short_columns "$table") || main_cols="$fields"
    main_cols=$(echo "$main_cols" | awk -F',' -v alias="$main_alias" '{for(i=1;i<=NF;i++) printf "%s%s.%s", (i>1?",":""), alias, $i}')

    local select_clause="SELECT ${main_cols}"
    if [ -n "$join" ]; then
        local join_cols=$(get_short_columns "$join_table")
        join_cols=$(echo "$join_cols" | awk -F',' -v alias="$join_alias" '{for(i=1;i<=NF;i++) printf "%s%s.%s", (i>1?",":""), alias, $i}')
        select_clause+=", ${join_cols}"
    fi

    local sql="${select_clause} FROM ${table} ${main_alias} ${join} WHERE ${condition} ${order_by} ${limit};"

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

# 获取所有表名（用于表名补全）
get_all_tables() {
    MYSQL_PWD="$DB_PASSWORD" \
    mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = '$DB_NAME'
    ORDER BY TABLE_NAME;" 2>/dev/null
}

# 获取完整表名
get_table_full_name() {
    local alias="$1"
    for entry in "${TABLE_ALIAS[@]}"; do
        if [[ "${entry%%:*}" == "$alias" ]]; then
            echo "${entry##*:}"
            return
        fi
    done
    echo "$alias"
}

# 获取表的所有字段
get_table_fields() {
    local table="$1"
    local full_table=$(get_table_full_name "$table")
    MYSQL_PWD="$DB_PASSWORD" \
    mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = '$DB_NAME'
      AND TABLE_NAME = '$full_table'
    ORDER BY ORDINAL_POSITION;" 2>/dev/null
}

# 将输入映射到完整表名
_get_full_table_name() {
    local input="$1"
    if [[ "$input" == lc_* ]]; then
        echo "$input"
    else
        for entry in "${TABLE_ALIAS[@]}"; do
            if [[ "${entry%%:*}" == "$input" ]]; then
                echo "${entry##*:}"
                return
            fi
        done
        echo "lc_$input"
    fi
}

# 主逻辑：执行查询
#query "$@"

# Zsh 补全与快捷键逻辑
if [[ -n "$ZSH_NAME" ]]; then
    # 字段缓存
    typeset -g -A TABLE_FIELDS
    _cache_table_fields() {
        local -a all_tables
        all_tables=($(get_all_tables))
        for tbl in "${all_tables[@]}"; do
            TABLE_FIELDS[$tbl]=$(get_short_columns "$tbl" | tr ',' ' ')
        done
    }

    _ensure_table_fields() {
        if [[ -z "${TABLE_FIELDS[lc_member]}" ]]; then
            _cache_table_fields
        fi
    }

    # 解析上下文中的表和别名
    _get_context_tables() {
        local buffer="$1"
        local -a tables
        tables=()

        if [[ "$buffer" =~ "query ([^ ]+)" ]]; then
            local main_input="${match[1]}"
            local main_full=$(_get_full_table_name "$main_input")
            local main_alias="$main_input"
            tables+=("$main_alias $main_full")
        fi

        while [[ "$buffer" =~ "j ([^ ]+)( .*)?$" ]]; do
            local join_input="${match[1]}"
            local join_full=$(_get_full_table_name "$join_input")
            local join_alias="$join_input"
            tables+=("$join_alias $join_full")
            buffer="${match[2]}"
        done

        echo "${tables[*]}"
    }

    _query_field_fzf() {
        if ! (( ${+commands[fzf]} )); then
            zle self-insert
            return
        fi

        local buffer="$LBUFFER"
        local selected

        # 情况 1：query 后提示表名
        if [[ "$buffer" =~ "^query[ ]*$" ]]; then
            selected=$(get_all_tables | fzf --prompt="选择表名 > " --height=40% --border --query="")
            if [ -n "$selected" ]; then
                LBUFFER="$buffer $selected"
                zle reset-prompt
            else
                LBUFFER="$buffer "
                zle reset-prompt
            fi
            tput cnorm  # 恢复光标
            return
        fi

        # 情况 2：j 后提示表名
        if [[ "$buffer" =~ "j[ ]*$" ]]; then
            selected=$(get_all_tables | fzf --prompt="选择 JOIN 表名 > " --height=40% --border --query="")
            if [ -n "$selected" ]; then
                LBUFFER="$buffer $selected"
                zle reset-prompt
            else
                LBUFFER="$buffer "
                zle reset-prompt
            fi
            tput cnorm  # 恢复光标
            return
        fi

        # 情况 3：表名后提示字段名
        local context=$(_get_context_tables "$buffer")
        local -a table_pairs
        table_pairs=("${(@s/ /)context}")

        if [ ${#table_pairs[@]} -eq 0 ]; then
            zle self-insert
            return
        fi

        local -a all_fields
        for pair in "${table_pairs[@]}"; do
            local alias="${pair%% *}"
            local full_table="${pair##* }"
            local fields=($(get_table_fields "$full_table"))
            for f in "${fields[@]}"; do
                all_fields+=("${alias}.$f")
            done
        done

        if [ ${#all_fields[@]} -eq 0 ]; then
            zle self-insert
            return
        fi

        selected=$(printf "%s\n" "${all_fields[@]}" | fzf --prompt="选择字段 > " --height=40% --border --query="")
        if [ -n "$selected" ]; then
            LBUFFER="$buffer $selected"
            zle reset-prompt
        else
            LBUFFER="$buffer "
            zle reset-prompt
        fi
        tput cnorm  # 恢复光标
    }

    # 绑定空格键
    zle -N _query_field_fzf
    bindkey " " _query_field_fzf

    # Tab 补全
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
                local -a options context_tables
                local context=$(_get_context_tables "$BUFFER")
                context_tables=("${(@s/ /)context}")
                context_tables=("${context_tables[@]%% *}")

                case "${words[$CURRENT-1]}" in
                    j)
                        options=("${all_tables[@]/%/:JOIN 表}")
                        ;;
                    limit)
                        options=("20" "50" "100")
                        ;;
                    *=*)
                        local -a fields
                        for tbl in "${context_tables[@]}"; do
                            local alias="$tbl"
                            local tbl_fields=($(get_table_fields "$tbl"))
                            for f in "${tbl_fields[@]}"; do
                                fields+=("${alias}.${f}")
                            done
                        done
                        options=("${fields[@]}")
                        ;;
                    *)
                        options=(
                            "j:加入 JOIN 表"
                            "where:添加 WHERE 条件"
                            "limit:限制结果数量"
                        )
                        local -a fields
                        for tbl in "${context_tables[@]}"; do
                            local alias="$tbl"
                            local tbl_fields=($(get_table_fields "$tbl"))
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

    compdef _query query

    # Option+T 触发表名选择
    if (( ${+commands[fzf]} )); then
        _query_fzf() {
            local buffer="$LBUFFER"
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
        }
        zle -N _query_fzf
        bindkey '†' _query_fzf
        bindkey '\M-t' _query_fzf
        bindkey '\e[116;3u' _query_fzf
    fi
fi
