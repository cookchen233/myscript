check_and_clean_orphans() {
    echo "正在查询孤儿记录..."
    orphans=$(MYSQL_PWD=$DB_PASSWORD mysql -t -h118.25.213.19 -u$DB_USER api_13012345822 <<EOF
SELECT DISTINCT member_id AS orphan_member_id
FROM (
    SELECT mt.member_id FROM lc_member_token mt WHERE mt.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT mw.member_id FROM lc_member_weixin mw WHERE mw.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT eo.member_id FROM lc_ec_order eo WHERE eo.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT es.member_id FROM lc_ec_shop es WHERE es.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT it.member_id FROM lc_insale_team it WHERE it.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT itm.member_id FROM lc_insale_team_member itm WHERE itm.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT ic.member_id FROM lc_insale_commission ic WHERE ic.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT tf.member_id FROM lc_insale_team_flow tf WHERE tf.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT tc.member_id FROM lc_insale_team_change tc WHERE tc.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT tr.member_id FROM lc_insale_team_rate tr WHERE tr.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT sa.member_id FROM lc_insale_salary sa WHERE sa.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
    UNION
    SELECT sl.member_id FROM lc_insale_salary_log sl WHERE sl.member_id NOT IN (SELECT member_id FROM lc_member WHERE member_id IS NOT NULL)
) AS orphans
WHERE member_id IS NOT NULL;
EOF
)

    echo "原始查询结果："
    echo "$orphans"
    echo "结果长度：${#orphans}"

    if [ -z "$orphans" ]; then
        echo "没有找到孤儿记录。"
        return 0
    fi

    echo "找到以下孤儿 member_id："
    echo "$orphans"
    echo

    while true; do
        read -p "是否删除这些记录？(y/n): " choice
        case $choice in
            [Yy]*)
                echo "正在删除孤儿记录..."
                MYSQL_PWD=$DB_PASSWORD mysql -h118.25.213.19 -u$DB_USER api_13012345822 <<EOF
DELETE mt, mw, eo, es, it, itm, ic, tf, tc, tr, sa, sl
FROM lc_member m
LEFT JOIN lc_member_token mt ON mt.member_id = m.member_id
LEFT JOIN lc_member_weixin mw ON mw.member_id = m.member_id
LEFT JOIN lc_ec_order eo ON eo.member_id = m.member_id
LEFT JOIN lc_ec_shop es ON es.member_id = m.member_id
LEFT JOIN lc_insale_team it ON it.member_id = m.member_id
LEFT JOIN lc_insale_team_member itm ON itm.member_id = m.member_id
LEFT JOIN lc_insale_commission ic ON ic.member_id = m.member_id
LEFT JOIN lc_insale_team_flow tf ON tf.member_id = m.member_id
LEFT JOIN lc_insale_team_change tc ON tc.member_id = m.member_id
LEFT JOIN lc_insale_team_rate tr ON tr.member_id = m.member_id
LEFT JOIN lc_insale_salary sa ON sa.member_id = m.member_id
LEFT JOIN lc_insale_salary_log sl ON sl.member_id = m.member_id
WHERE m.member_id IS NULL
  AND (mt.member_id IS NOT NULL
    OR mw.member_id IS NOT NULL
    OR eo.member_id IS NOT NULL
    OR es.member_id IS NOT NULL
    OR it.member_id IS NOT NULL
    OR itm.member_id IS NOT NULL
    OR ic.member_id IS NOT NULL
    OR tf.member_id IS NOT NULL
    OR tc.member_id IS NOT NULL
    OR tr.member_id IS NOT NULL
    OR sa.member_id IS NOT NULL
    OR sl.member_id IS NOT NULL);
EOF
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
}

check_and_clean_orphans