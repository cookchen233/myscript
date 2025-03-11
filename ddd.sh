#!/bin/bash

# 检查必要的环境变量是否存在
if [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ]; then
    echo "错误：请在 ~/.zshrc 中定义 DB_HOST, DB_USER, DB_PASSWORD 和 DB_NAME"
    exit 1
fi

# 白名单表（用空格分隔）
WHITELIST_TABLES=(
    "appeal"
    "category"
    "lc_cn_area"
    "lc_ec_express_company"
    "user"
    "lc_menu"
    "lc_site_menu"
    "lc_role"
    "lc_admin_user"
    "lc_article"
    "lc_category"
    "lc_config"
    "lc_ec_product"
    "lc_ec_product_category"
    "lc_ec_product_tag"
    "lc_ec_product_to_product_tag"
    "lc_ec_sku"
    "lc_ec_spec"
    "lc_ec_spec_value"
    "lc_label"
    "lc_pan"
    "lc_site"
)

# 从命令行参数获取 site_id
if [ -z "$1" ]; then
    echo "错误：请提供 site_id 参数，例如：./script.sh 20"
    exit 1
fi
SITE_ID="$1"

# 临时文件存储表信息
TEMP_FILE="/tmp/mysql_tables_to_delete.txt"

# 获取所有表名
echo "正在检查数据库 $DB_NAME 中的表..."
MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -N -e "SHOW TABLES FROM $DB_NAME" > "$TEMP_FILE"

# 存储需要清理的表
TABLES_TO_DELETE=()

# 检查每个表是否有 site_id 字段，并确认是否有匹配数据
while read -r table; do
    # 检查是否在白名单中
    skip_table=false
    for whitelist_table in "${WHITELIST_TABLES[@]}"; do
        if [ "$table" = "$whitelist_table" ]; then
            # echo "跳过白名单表: $table"
            skip_table=true
            break
        fi
    done
    [ "$skip_table" = true ] && continue

    # 检查表是否有 site_id 字段
    HAS_SITE_ID=$(MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -N -e \
        "SHOW COLUMNS FROM $table FROM $DB_NAME WHERE Field = 'site_id'")

    if [ -n "$HAS_SITE_ID" ]; then
        # 检查表中是否存在 site_id = $SITE_ID 的数据
        RECORD_COUNT=$(MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -N -e \
            "SELECT COUNT(*) FROM $DB_NAME.$table WHERE site_id = '$SITE_ID'")
        
        # if [ "$RECORD_COUNT" -gt 0 ]; then
        #     TABLES_TO_DELETE+=("$table")
        #     echo "表 $table 包含 site_id = $SITE_ID 的数据 ($RECORD_COUNT 条记录)"
        # else
        #     echo "表 $table 有 site_id 字段，但无 site_id = $SITE_ID 的数据，跳过"
        # fi
    else
        echo "表 $table 无 site_id 字段，跳过"
        echo "$table"
    fi
done < "$TEMP_FILE"

# 如果没有需要清理的表，退出
if [ ${#TABLES_TO_DELETE[@]} -eq 0 ]; then
    echo "没有符合条件的表需要清理。"
    rm -f "$TEMP_FILE"
    exit 0
fi

# 显示将要清理的表并要求确认
echo -e "\n以下表的 site_id = $SITE_ID 数据将被清理："
for table in "${TABLES_TO_DELETE[@]}"; do
    echo "  - $table"
done

echo -n "确认要清理这些表的数据吗？(y/N): "
read -r CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" && "$CONFIRM" != "" ]]; then
    echo "操作已取消。"
    rm -f "$TEMP_FILE"
    exit 0
fi

# 执行清理操作
echo "开始清理表数据..."
for table in "${TABLES_TO_DELETE[@]}"; do
    echo "清理表: $table"
    # 执行 DELETE 操作
    MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -e \
        "DELETE FROM $DB_NAME.$table WHERE site_id = '$SITE_ID'"
    if [ $? -eq 0 ]; then
        echo "表 $table 清理成功"
    else
        echo "表 $table 清理失败"
    fi
done

# 清理临时文件
rm -f "$TEMP_FILE"
echo "清理完成。"