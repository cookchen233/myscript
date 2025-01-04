from datetime import datetime
import jinja2
import os
import pymysql

from alphagen.utils import camel_to_snake, snake_to_camel


class BaseGenerator(object):
    def __init__(self, file_name, rendered_file_dir=""):
        self.table_prefix = None
        self.module_name = None
        self.file_name = file_name
        self.pymysql_connection = None
        self.rendered_file_dir = rendered_file_dir

        templates_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)), '../templates')
        self.jinja2_env = jinja2.Environment(loader=jinja2.FileSystemLoader(templates_dir))

        self.jinja2_env.filters['camel_to_snake'] = camel_to_snake
        self.jinja2_env.filters['snake_to_camel'] = snake_to_camel

        self.force = False  # 添加force属性

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix

    def generated_file_name(self):
        return self.file_name+".php"

    def set_force(self, force):
        self.force = force

    def set_site_id(self, site_id):
        self.site_id = site_id

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


    def get_table_comment(self, clean=True):
        # 获取中文表名（从表注释中提取）
        import re
        base_name = re.sub(r'Model|Controller|ApiController', '', self.file_name)
        table_name = self.table_prefix + camel_to_snake(base_name)
        table_comment = self._get_table_status(table_name, "Comment")
        if not table_comment:
            table_comment = table_name

        # 移除表注释中可能的额外描述（通常在括号内）
        if clean:
            return self.clean_comment(table_comment)
        return table_comment

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
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

    def _parse_enum_values(self, comment: str) -> list:
        """从注释中解析枚举值"""
        enum_items = []
        if '[' in comment and ']' in comment:
            # 提取方括号中的内容
            start = comment.find('[')
            end = comment.find(']', start)
            if end == -1:
                return enum_items

            enum_part = comment[start + 1:end]

            # 处理多个方括号的情况
            if '[' in enum_part:
                return self._parse_enum_values(enum_part)

            # 分割枚举项
            items = [item.strip() for item in enum_part.split(',')]

            for item in items:
                if ':' in item:
                    try:
                        key, value = item.strip().split(':')
                        enum_items.append({
                            'key': key.strip(),
                            'value': value.strip(),
                            'constant_name': f'V{key.strip()}'
                        })
                    except Exception as e:
                        print("枚举类型备注格式有误, 解析结果: ", items)
                        raise e
        return enum_items

    def _get_enum_fields(self, table_name: str) -> list:
        """获取表中的枚举字段"""
        schema = self._get_table_schema(table_name)
        enum_fields = []

        excludes = [
            "gender"
        ]

        for field in schema:
            if field["Field"] in excludes:
                continue

            # 检查是否是枚举字段
            is_enum = False

            # 1. tinyint 类型且有枚举值注释
            if field['Type'].startswith('tinyint'):
                comment = field['Comment']
                if '[' in comment and ']' in comment and ':' in comment:
                    is_enum = True

            if is_enum:
                enum_items = self._parse_enum_values(field['Comment'])
                if enum_items:  # 只有解析出枚举值才添加
                    enum_field = {
                        'field_name': field['Field'],
                        'comment': field['Comment'],
                        'enum_items': enum_items
                    }
                    enum_fields.append(enum_field)

        return enum_fields

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

        # 检查注释是否包含枚举定义 [1:xx, 2:yy] 格式
        if any(c.isdigit() for c in comment) and ":" in comment and "," in comment and "[" in comment and "]" in comment and base_type == "number":
            return "enum"

        # 检查是否包含关联ID [id:xx] 格式
        if "[id:" in comment and "]" in comment and base_type == "number":
            return "data-id"

        if "_img" in field_name or "_image" in field_name:
            return "image"

        if "file" in field_name or "files" in field_name:
            return "file"

        if "_time" in field_name or "_date" in field_name or base_type == "datetime" or base_type == "date":
            return "datetime"

        if base_type == "longtext":
            return "textarea"

        return "text"

    def get_template_name(self):
        raise NotImplementedError("Subclasses must implement get_template_name()")

    def get_template_variables(self):
        raise NotImplementedError("Subclasses must implement get_template_variables()")

    def _get_model_properties(self, table_name):
        table_schema = self._get_table_schema(table_name)
        model_properties = []

        # 排除的字段列表
        exclude_fields = ['password', 'delete_time', 'update_time',
                          'site_id', 'create_time', 'id']

        for field in table_schema:
            field_name = field["Field"].lower()
            field_type = field["Type"].lower()

            # 确定字段类型
            if any(t in field_type for t in ['int', 'float', 'decimal']):
                property_type = "int"
                example_value = 1
            elif 'datetime' in field_type:
                property_type = "string"
                example_value = "2024-01-01 00:00:00"
            elif 'date' in field_type:
                property_type = "string"
                example_value = "2024-01-01"
            else:
                property_type = "string"
                example_value = "示例文本"

            # 特殊字段的示例值处理
            if 'status' in field_name or 'type' in field_name or 'level' in field_name:
                example_value = 1
            elif 'email' in field_name:
                example_value = "example@domain.com"
            elif 'phone' in field_name or 'mobile' in field_name:
                example_value = "13800138000"
            elif 'url' in field_name or 'website' in field_name:
                example_value = "http://example.com"
            elif ('enabled' in field_name or 'disabled' in field_name or 'is_' in field_name) and 'tinyint' in field_type:
                example_value = 1

            # 判断是否作为参数
            is_parameter = field["Field"] not in exclude_fields and 'text' not in field_type

            model_property = dict(
                name=snake_to_camel(field["Field"]),
                property_type=property_type,
                field_name=field["Field"],
                field_comment=field["Comment"],
                is_parameter=is_parameter,
                example_value=example_value,
                set_method_name=snake_to_camel("set_" + field["Field"]),
                get_method_name=snake_to_camel("get_" + field["Field"]),
            )
            model_properties.append(model_property)

        return model_properties

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
        filename = os.path.join(self.rendered_file_dir, self.generated_file_name())

        # 确保目录存在
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        if not self._should_update_file(filename):
            print(f'Skipping file: {filename} (manually created or modified)')
            return

        with open(filename, "w", encoding='utf-8') as f:
            f.write(rendered)
            print(f'Successfully generated: {filename}')
