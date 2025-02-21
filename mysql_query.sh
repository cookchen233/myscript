#!/usr/bin/env bash

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
                [ -z "$join_table" ] && join_table="lc_$1"
                shift
                if [ -n "$1" ] && [[ ! "$1" =~ (asc|desc|limit) ]]; then
                    local join_condition="$1"
                    join_condition="${join_condition//${main_alias}./${table}.}"
                    join_condition="${join_condition//${join_alias}./${join_alias}.}"  # 使用别名而不是表名
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