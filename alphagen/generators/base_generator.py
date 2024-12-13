from datetime import datetime
import jinja2
import os
import pymysql

from alphagen.utils import camel_to_snake, snake_to_camel


class BaseGenerator(object):
    def __init__(self, file_name, rendered_file_dir=""):
        self.file_name = file_name
        self.pymysql_connection = None
        self.rendered_file_dir = rendered_file_dir

        templates_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), '../templates')
        self.jinja2_env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))

        self.jinja2_env.filters['camel_to_snake'] = camel_to_snake
        self.jinja2_env.filters['snake_to_camel'] = snake_to_camel

        self.force = False  # 添加force属性

    def set_force(self, force):
        self.force = force

    def __del__(self):
        if hasattr(self, 'pymysql_connection') and self.pymysql_connection is not None:
            self.pymysql_connection.close()

    def set_mysql_connection(self, host='localhost', port=3306, user='root', password='', db='baibuyinshe',
                             charset='utf8'):
        self.pymysql_connection = pymysql.connect(host=host, port=port, user=user, password=password, db=db,
                                                  charset=charset)

    def _get_table_schema(self, table_name):
        with self.pymysql_connection.cursor() as cursor:
            query = f"SHOW FULL COLUMNS FROM {table_name}"
            cursor.execute(query)
            return self._get_rows_from_cursor(cursor)

    def _get_table_status(self, table_name, key):
        try:
            with self.pymysql_connection.cursor() as cursor:
                cursor.execute("SELECT DATABASE()")
                current_db = cursor.fetchone()[0]

                query = f"SHOW TABLE STATUS LIKE '{table_name}'"
                cursor.execute(query)
                row = cursor.fetchone()

                if row is None:
                    raise Exception(f"数据库[{current_db}]找不到表[{table_name}]")

                field_names = [desc[0] for desc in cursor.description]
                row_dict = dict(zip(field_names, row))
                return row_dict[key]

        except Exception as e:
            print(f"错误信息: {str(e)}")
            print(f"数据库连接信息: {self.pymysql_connection.get_host_info()}")
            raise

    def clean_comment(self,comment):
        """
        Clean comment by removing enum-like descriptions in square brackets
        Example: "日志类型[1:类型1, 2:类型2, 3:xx]" -> "日志类型"
        """
        if not comment:
            return comment

        # Find first [ character position
        bracket_start = comment.find('[')
        if bracket_start != -1:
            return comment[:bracket_start].strip()

        return comment.strip()

    def _get_rows_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchall()
        rows = []
        for row in result:
            rows.append(dict(zip(column_names, row)))
        return rows

    def _get_field_base_type(self, field):
        """
        获取字段的基础数据类型(number,string,longtext,date,time,datetime)
        Args:
            field: 数据库字段信息字典
        Returns:
            str: 字段对应的基础类型
        """
        field_type = field["Type"].lower()

        # 数值类型映射
        number_types = [
            "int", "tinyint", "smallint", "mediumint", "bigint",  # 整数类型
            "decimal", "float", "double", "numeric"  # 浮点数类型
        ]

        # 文本类型映射
        text_types = [
            "text", "mediumtext", "longtext", "tinytext",  # 长文本类型
            "varchar", "char"  # 短文本类型
        ]

        # 日期时间类型映射
        datetime_types = [
            "datetime", "timestamp", "date", "time"
        ]

        # 检查类型前缀
        type_prefix = field_type.split('(')[0]  # 处理如 varchar(255) 的情况

        # 数值类型判断
        if any(t in type_prefix for t in number_types):
            if "decimal" in type_prefix or "float" in type_prefix or "double" in type_prefix:
                return "number"
            return "number"

        # 文本类型判断
        if any(t in type_prefix for t in text_types):
            if any(t in type_prefix for t in ["text", "mediumtext", "longtext", "tinytext"]):
                return "longtext"
            return "string"

        # 日期时间类型判断
        if any(t in type_prefix for t in datetime_types):
            if "date" == type_prefix:
                return "date"
            if "time" == type_prefix:
                return "time"
            return "datetime"

        # 其他类型
        type_mapping = {
            "json": "json",
            "blob": "blob",
            "binary": "binary",
            "bool": "boolean",
            "boolean": "boolean",
            "enum": "enum",
            "set": "set"
        }

        for db_type, mapped_type in type_mapping.items():
            if db_type in type_prefix:
                return mapped_type

        # 默认返回文本类型
        return "string"

    def _get_field_display_type(self, field):
        """
        获取字段在界面上的展示类型
        """
        field_name = field["Field"].lower()
        field_type = field["Type"].lower()
        base_type = self._get_field_base_type(field)
        comment = field["Comment"]

        # 通用的类型判断逻辑
        if field_name.startswith("is_") and "tinyint" in field_type:
            return "switch"

        if any(word in field_name for word in ["_status", "_type", "_level"]) and "tinyint" in field_type:
            return "enum"

        if "[id:" in comment and "]" in comment and base_type == "number":
            return "data-id"

        if "img" in field_name:
            return "image"

        if "file" in field_name or "files" in field_name:
            return "file"

        if "_time" in field_name or "_date" in field_name or base_type == "datetime" or base_type == "date":
            return "datetime"

        if base_type == "longtext":
            return "textarea"

        return "text"

    def _get_enum_fields(self, table_name):
        """
        获取枚举字段（不包含switch类型）
        """
        table_schema = self._get_table_schema(table_name)
        enum_fields = []

        for field in table_schema:
            field_name = field["Field"].lower()
            display_type = self._get_field_display_type(field)

            # 只处理enum类型
            if display_type == "enum":
                enum_name = snake_to_camel(field_name)
                options_name = enum_name + "Options"
                enum_fields.append({
                    "field": field_name,
                    "enum_name": enum_name,
                    "options_name": options_name,
                    "comment": field["Comment"]
                })

        return enum_fields


    def get_template_name(self):
        raise NotImplementedError("Subclasses must implement get_template_name()")

    def get_template_variables(self):
        raise NotImplementedError("Subclasses must implement get_template_variables()")

    def render(self):
        template = self.jinja2_env.get_template(self.get_template_name())
        return template.render(self.get_template_variables())

    def _should_update_file(self, filename: str) -> bool:
        """检查是否应该更新现有文件"""
        if not os.path.exists(filename):
            return True

        # 读取现有文件的生成时间
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            if '@generated by AlphaGenerator' not in content:
                # 如果文件中没有生成标记，认为是手动创建的文件
                return False
        return True

    def _add_file_header(self, content: str) -> str:
        """Add a file header comment."""
        now = datetime.now()
        formatted_date = now.strftime("%B %d, %Y")  # Format: November 29, 2024
        formatted_time = now.strftime("%H:%M:%S")    # Format: 21:07:04

        header = f"""<?php
/**
 * This file is auto-generated.
 * If you delete the tag "@generated ...", this file will not be generated again.
 * @generated by AlphaGenerator on {formatted_date}, at {formatted_time}
*/
"""
        return header + content.lstrip('<?php')

    def generate(self):
        rendered = self._add_file_header(self.render())

        if self.rendered_file_dir == "":
            self.rendered_file_dir = os.path.join(os.path.dirname(os.path.realpath(__file__) + "/.../"), "rendered_files")
        os.makedirs(os.path.dirname(self.rendered_file_dir), exist_ok=True)
        filename = os.path.join(self.rendered_file_dir, self.file_name + ".php")

        # 确保目录存在
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        if not self._should_update_file(filename):
            print(f'Skipping file: {filename} (manually created or modified)')
            return

        with open(filename, "w", encoding='utf-8') as f:
            f.write(rendered)
            print(f'Successfully generated: {filename}')
