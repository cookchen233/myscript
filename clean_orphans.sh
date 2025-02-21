#!/usr/bin/env bash

DB_HOST="118.25.213.19"
DB_NAME="api_13012345822"
DB_USER="waynechen"
DB_PASSWORD="Cc@123456"

# 默认站点 ID
: ${SITE_ID:=20}

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
# 示例调用
# -----------------------------
# check_and_clean_orphans
# delete_member_and_related 444
# -----------------------------
check_and_clean_orphans() {
    echo "查询孤儿记录..."

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
                    echo "删除孤儿记录..."
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

    echo "查询 member_id=${member_id} 相关记录..."

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