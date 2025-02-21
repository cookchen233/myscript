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

RELATED_TABLES=(
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
        ORDER BY ORDINAL_POSITION;"
    )
    [ -z "$cols" ] && echo "id" || echo "$cols" | tr '\n' ',' | sed 's/,$//'
}

query() {
    local table="lc_member"
    local condition=""
    local join=""
    local order_limit="LIMIT 10"
    local verbose=1
    local fields=""
    local nowrap=1
    local primary_key="id"

    while [[ "$1" =~ ^- ]]; do
        case "$1" in
            -v) verbose=1; shift;;
            -n) nowrap=1; shift;;
            *) echo "未知选项: $1"; return 1;;
        esac
    done

    # 解析表名，优先检查别名
    if [ -n "$1" ]; then
        local found=0
        for entry in "${RELATED_TABLES[@]}"; do
            local alias="${entry%%:*}"
            local full_table="${entry##*:}"
            if [ "$1" = "$alias" ]; then
                table="$full_table"
                found=1
                shift
                break
            fi
        done
        # 如果不是别名，且不是数字或键值对，则添加 lc_ 前缀
        if [ "$found" -eq 0 ] && [[ "$1" != [0-9]* ]] && [[ "$1" != *=* ]]; then
            table="lc_$1"
            shift
        fi
    fi

    primary_key=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -N -e "
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = '$DB_NAME'
          AND TABLE_NAME = '$table'
          AND COLUMN_KEY = 'PRI'
        LIMIT 1;" || echo "id"
    )
    [ -z "$primary_key" ] && primary_key="id"

    while [ -n "$1" ]; do
        case "$1" in
            [0-9]*) condition="${condition:+$condition AND }${primary_key} = '$1'";;
            j)
                shift
                [ -z "$1" ] && { echo "缺少 JOIN 表名"; return 1; }
                local join_table="lc_$1"
                local alias="$1"
                shift
                if [[ "$1" =~ ^on= ]]; then
                    join="LEFT JOIN ${join_table} ${alias} ON ${1#on=}"
                    shift
                else
                    join="LEFT JOIN ${join_table} ${alias} ON ${alias}.${alias}_id = ${table##lc_}.${primary_key}"
                fi
                ;;
            f=*) fields="${1#f=}";;
            o=*) order_limit="ORDER BY ${1#o=}";;
            l=*) order_limit="${order_limit/ LIMIT*/} LIMIT ${1#l=}";;
            d) order_limit="ORDER BY ${primary_key} DESC LIMIT 10";;
            a) order_limit="ORDER BY ${primary_key} ASC LIMIT 10";;
            *=*) 
                local cond="${1//=/ = }"
                if [[ "$cond" =~ ^[a-zA-Z_]+\ += ]]; then
                    condition="${condition:+$condition AND }$cond"
                else
                    condition="${condition:+$condition AND }${table}.${cond}"
                fi
                ;;
            *) echo "无效参数: $1"; return 1;;
        esac
        shift
    done

    local site_condition="${table}.site_id = ${SITE_ID}"
    if [ -n "$join" ]; then
        site_condition+=" AND ${join_table}.site_id = ${SITE_ID}"
    fi
    condition="WHERE $site_condition${condition:+ AND $condition}"

    local main_cols
    [ -z "$fields" ] && main_cols=$(get_short_columns "$table") || main_cols="$fields"
    local select_clause="SELECT ${table}.${main_cols}"
    if [ -n "$join" ]; then
        local join_cols=$(get_short_columns "$join_table")
        select_clause+=", ${alias}.${join_cols}"
    fi

    local sql="$select_clause FROM ${table} ${join} ${condition} ${order_limit};"

    if [ "$verbose" -eq 1 ]; then
        echo "查询: ${table}${join:+ + $alias}"
        echo "主键: $primary_key"
        echo "字段: ${main_cols}${join:+, $join_cols}"
        echo "SQL: $sql"
    else
        echo "查询: ${table}${join:+ + $alias}"
    fi

    if [ "$nowrap" -eq 1 ]; then
        tput rmam
        MYSQL_PWD="$DB_PASSWORD" \
            mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>/dev/null || echo "查询失败"
        tput smam
    else
        result=$(
            MYSQL_PWD="$DB_PASSWORD" \
            mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>/dev/null
        )
        [ -z "$result" ] && echo "无记录" || echo "$result"
    fi
}