#!/usr/bin/env bash

# 相关联表（别名:表名）
RELATED_TABLES=(
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
# 函数：清理“孤儿记录”（不删除 lc_member）
# -----------------------------
check_and_clean_orphans() {
    echo "正在查询孤儿记录..."

    # 动态生成 UNION ALL 查询
    # 将每张表里 “member_id 在 lc_member 中不存在” 的行 UNION 汇总
    union_query=""
    for table_entry in "${RELATED_TABLES[@]}"; do
        alias="${table_entry%%:*}"
        table="${table_entry##*:}"

        union_query+="SELECT '${alias}' AS table_alias, t.member_id
FROM ${table} t
LEFT JOIN lc_member m ON t.member_id = m.member_id
WHERE m.member_id IS NULL
UNION ALL
"
    done

    # 去除末尾多余的 "UNION ALL"
    union_query="${union_query%UNION ALL
}"

    # 如果 union_query 依然为空，说明没有任何要查的表，直接退出
    if [ -z "$union_query" ]; then
        echo "没有可执行的查询语句，RELATED_TABLES 可能为空。"
        return 0
    fi

    # 执行查询
    orphans=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" <<EOF
${union_query};
EOF
    )

    echo "原始查询结果："
    echo "$orphans"
    echo "结果长度：${#orphans}"

    # 如果结果太短，可能意味着没有找到孤儿记录
    if [ -z "$orphans" ] || [ "${#orphans}" -lt 10 ]; then
        echo
        echo "没有找到孤儿记录或查询结果为空。"
        return 0
    fi

    echo
    echo "找到以下孤儿记录：（表别名 | member_id）"
    echo "$orphans"
    echo

    # 交互式删除
    if [ -t 0 ]; then
        while true; do
            # 方式1：zsh 下
            read "choice?是否删除这些孤儿记录？(y/n): "

            # 方式2：必须在bash下
            # echo -n "是否删除这些孤儿记录？(y/n): "
            # read choice

            case "$choice" in
                [Yy]*|"")  # 添加 "" 表示回车默认确认
                    echo "正在删除孤儿记录..."
                    for table_entry in "${RELATED_TABLES[@]}"; do
                        table="${table_entry##*:}"
                        # 只删除 该子表中 LEFT JOIN lc_member 不匹配的记录
                        MYSQL_PWD="$DB_PASSWORD" \
                        mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" <<EOF
DELETE t
FROM ${table} t
LEFT JOIN lc_member m ON t.member_id = m.member_id
WHERE m.member_id IS NULL;
EOF
                    done
                    echo
                    echo "删除完成。"
                    break
                    ;;
                [Nn]*)
                    echo "取消删除操作。"
                    break
                    ;;
                *)
                    echo "请输入 y 或 n（回车默认执行删除）。"
                    ;;
            esac
            done
    else
        echo "非交互式环境，无法提示确认。请在终端运行以确认删除。"
        return 1
    fi
}

# -----------------------------
# 函数：删除指定 member_id 及其所有关联
# -----------------------------
delete_member_and_related() {
    if [ -z "$1" ]; then
        echo "请提供要删除的会员ID (member_id)"
        return 1
    fi

    member_id="$1"

    echo "正在查询与 member_id=${member_id} 相关的记录..."

    select_clause="SELECT m.member_id AS m_member_id, "
    join_clause=""
    for table_entry in "${RELATED_TABLES[@]}"; do
        alias="${table_entry%%:*}"
        table="${table_entry##*:}"
        select_clause+="${alias}.member_id AS ${alias}_member_id, "
        join_clause+="LEFT JOIN ${table} ${alias} ON ${alias}.member_id = m.member_id
"
    done
    select_clause="${select_clause%, }"

    related=$(
        MYSQL_PWD="$DB_PASSWORD" \
        mysql -t -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" <<EOF
${select_clause}
FROM lc_member m
${join_clause}
WHERE m.member_id = '${member_id}';
EOF
    )

    if [ -z "$related" ] || [ "${#related}" -lt 10 ]; then
        echo
        echo "未在所有关联表中找到 member_id=${member_id} 的相关记录。"
        echo "如需确认请手动检查。"
        return 0
    fi

    echo
    echo "找到以下相关记录："
    echo "$related"
    echo

    # 交互式删除确认
    if [ -t 0 ]; then
        while true; do
            read "choice?是否删除 member_id=${member_id} 及其所有相关记录？(y/n): "
            case "$choice" in
                [Yy]*|"")
                    echo "正在删除 member_id=${member_id} 及其相关记录..."
                    delete_tables="m"
                    for table_entry in "${RELATED_TABLES[@]}"; do
                        alias="${table_entry%%:*}"
                        delete_tables+=",${alias}"
                    done

                    MYSQL_PWD="$DB_PASSWORD" \
                    mysql -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" <<EOF
DELETE ${delete_tables}
FROM lc_member m
${join_clause}
WHERE m.member_id = '${member_id}';
EOF

                    echo
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
    else
        echo "非交互式环境，无法提示确认。请在终端运行以确认删除。"
        return 1
    fi
}

# -----------------------------
# 示例调用
# -----------------------------
# check_and_clean_orphans
# delete_member_and_related 444


# -----------------------------
# 环境变量：默认站点 ID
# 可通过 export SITE_ID=xx 设置
# -----------------------------
: ${SITE_ID:=20}  # 默认值为 20，若未设置则使用此值

# -----------------------------
# 函数：查询指定表的数据
# 用法示例：
#   query s 123               # lc_ec_shop id=123 AND site_id=20
#   query s n=test            # lc_ec_shop name='test' AND site_id=20
#   query s j o s=1           # lc_ec_shop JOIN lc_ec_order WHERE status=1 AND site_id=20
#   query s n=test d          # lc_ec_shop name='test' AND site_id=20 ORDER BY id DESC LIMIT 10
#   query d                   # lc_member site_id=20 ORDER BY id DESC LIMIT 10
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

# 示例调用
# query d
# query -v s 123
# query s n=test o=id desc
# query s j o on=o.shop_id=es.id s=1
# query s f=id,name d