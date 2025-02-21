#!/usr/bin/env bash

DB_HOST="118.25.213.19"
DB_NAME="api_13012345822"
DB_USER="waynechen"
DB_PASSWORD="Cc@123456"

# 默认站点 ID
: ${SITE_ID:=20}

# 相关联表（别名:表名）
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

# -----------------------------
# 函数：查询指定表的数据
# 用法示例：
#   query es 123               # lc_ec_shop id=123 AND site_id=20
#   query es n=test            # lc_ec_shop name='test' AND site_id=20
#   query es j o s=1           # lc_ec_shop JOIN lc_ec_order WHERE status=1 AND site_id=20
#   query es n=test d          # lc_ec_shop name='test' AND site_id=20 ORDER BY id DESC LIMIT 10
#   query es name=xx                   # lc_ec_shop site_id=20 and name="xx" ORDER BY id DESC LIMIT 10
#   query name=xx                   # lc_member site_id=20 and name="xx" ORDER BY member_id(primary key) DESC LIMIT 10
#   ...请补充更多强大, 又简单的命令
# -----------------------------


# 获取表的短字段
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
    local table="lc_member"  # 默认表
    local condition=""
    local join=""
    local order_limit="LIMIT 10"
    local verbose=0
    local fields=""

    # 检查是否启用调试模式
    [ "$1" = "-v" ] && { verbose=1; shift; }

    # 单参数排序
    if [ "$1" = "d" ] || [ "$1" = "a" ]; then
        order_limit="ORDER BY id $([ "$1" = "d" ] && echo DESC || echo ASC) LIMIT 10"
    else
        # 表名
        if [ -n "$1" ]; then
            if [ "${#1}" -eq 1 ]; then
                for entry in "${RELATED_TABLES[@]}"; do
                    if [[ "$entry" =~ ^${1}: ]]; then
                        table="${entry##*:}"
                        break
                    fi
                done
            else
                table="lc_${1}"
            fi
        fi

        # 参数解析
        local i=2
        while [ -n "${!i}" ]; do
            local arg="${!i}"
            case "$arg" in
                [0-9]*) condition="WHERE id = $arg";;
                j)  # JOIN
                    ((i++))
                    local join_table="lc_${!i}"
                    local alias="${!i}"
                    ((i++))
                    if [[ "${!i}" =~ ^on= ]]; then
                        join="LEFT JOIN ${join_table} ${alias} ON ${!i#on=}"
                    else
                        join="LEFT JOIN ${join_table} ${alias} ON ${alias}.${alias}_id = ${table##lc_}.id"
                        [ -n "${!i}" ] && condition="WHERE ${!i//=/ = }"
                    fi
                    ;;
                f=*) fields="${arg#f=}";;
                o=*) order_limit="ORDER BY ${arg#o=} LIMIT 10";;
                *) condition="WHERE ${arg//=/ = }";;
            esac
            ((i++))
        done
    fi

    # 添加 site_id 条件
    local site_condition="${table}.site_id = ${SITE_ID}"
    if [ -n "$join" ]; then
        site_condition+=" AND ${join_table}.site_id = ${SITE_ID}"
    fi
    if [ -n "$condition" ]; then
        condition="${condition/WHERE/WHERE $site_condition AND}"
    else
        condition="WHERE $site_condition"
    fi

    # 字段选择
    local main_cols
    [ -z "$fields" ] && main_cols=$(get_short_columns "$table") || main_cols="$fields"
    local select_clause="SELECT ${table}.${main_cols}"
    if [ -n "$join" ]; then
        local join_cols=$(get_short_columns "$join_table")
        select_clause+=", ${join_table}.${join_cols}"
    fi

    # 生成 SQL
    sql="$select_clause FROM ${table} ${join} ${condition} ${order_limit};"
    
    # 输出
    if [ "$verbose" -eq 1 ]; then
        echo "查询: ${table}${join:+ + $alias}"
        echo "字段: ${main_cols}${join:+, $join_cols}"
        echo "SQL: $sql"
    else
        echo "查询: ${table}${join:+ + $alias}"
    fi

    # 执行查询
    result=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>/dev/null
    )
    [ -z "$result" ] && echo "无记录" || echo "$result"
}

# 获取表的短字段
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

# 示例调用
# query 1
# query -v s 123
# query s n=test o=id desc
# query s j o on=o.shop_id=es.id s=1
# query s f=id,name d
query() {
    local table="lc_member"  # 默认表
    local condition=""
    local join=""
    local order_limit="LIMIT 10"
    local verbose=0
    local fields=""
    local nowrap=1  # 是否禁用换行

    # 检查选项
    while [[ "$1" =~ ^- ]]; do
        [ "$1" = "-v" ] && { verbose=1; shift; }
        [ "$1" = "-n" ] && { nowrap=1; shift; }  # -n 表示不换行
    done

    # 单参数排序
    if [ "$#" -eq 1 ] && { [ "$1" = "d" ] || [ "$1" = "a" ]; }; then
        order_limit="ORDER BY id $([ "$1" = "d" ] && echo DESC || echo ASC) LIMIT 10"
    else
        # 表名
        if [ -n "$1" ]; then
            if [ "${#1}" -eq 1 ]; then
                for entry in "${RELATED_TABLES[@]}"; do
                    if [[ "$entry" =~ ^${1}: ]]; then
                        table="${entry##*:}"
                        break
                    fi
                done
            else
                table="lc_${1}"
            fi
            shift
        fi

        # 参数解析
        while [ "$#" -gt 0 ]; do
            case "$1" in
                [0-9]*) condition="WHERE id = $1";;
                j)  # JOIN
                    shift
                    if [ -z "$1" ]; then echo "缺少 JOIN 表名"; return 1; fi
                    local join_table="lc_${1}"
                    local alias="$1"
                    shift
                    if [[ "$1" =~ ^on= ]]; then
                        join="LEFT JOIN ${join_table} ${alias} ON ${1#on=}"
                        shift
                    else
                        join="LEFT JOIN ${join_table} ${alias} ON ${alias}.${alias}_id = ${table##lc_}.id"
                    fi
                    [ -n "$1" ] && [[ ! "$1" =~ ^(f=|o=) ]] && condition="WHERE ${1//=/ = }"
                    ;;
                f=*) fields="${1#f=}";;
                o=*) order_limit="ORDER BY ${1#o=} LIMIT 10";;
                *) condition="WHERE ${1//=/ = }";;
            esac
            shift
        done
    fi

    # 添加 site_id 条件
    local site_condition="${table}.site_id = ${SITE_ID}"
    if [ -n "$join" ]; then
        site_condition+=" AND ${join_table}.site_id = ${SITE_ID}"
    fi
    if [ -n "$condition" ]; then
        condition="${condition/WHERE/WHERE $site_condition AND}"
    else
        condition="WHERE $site_condition"
    fi

    # 字段选择
    local main_cols
    [ -z "$fields" ] && main_cols=$(get_short_columns "$table") || main_cols="$fields"
    local select_clause="SELECT ${table}.${main_cols}"
    if [ -n "$join" ]; then
        local join_cols=$(get_short_columns "$join_table")
        select_clause+=", ${join_table}.${join_cols}"
    fi

    # 生成 SQL
    sql="$select_clause FROM ${table} ${join} ${condition} ${order_limit};"

    # 输出调试信息
    if [ "$verbose" -eq 1 ]; then
        echo "查询1: ${table}${join:+ + $alias}"
        echo "字段: ${main_cols}${join:+, $join_cols}"
        echo "SQL: $sql"
    else
        echo "查询: ${table}${join:+ + $alias}"
    fi

    # 执行查询
    if [ "$nowrap" -eq 1 ]; then
        # 禁用换行
        tput rmam
        result=$(
            MYSQL_PWD="$DB_PASSWORD" \
            mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>/dev/null
        )
        echo "$result"
        # 恢复换行
        tput smam
    else
        result=$(
            MYSQL_PWD="$DB_PASSWORD" \
            mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" -e "$sql" 2>/dev/null
        )
        [ -z "$result" ] && echo "无记录" || echo "$result"
    fi
}