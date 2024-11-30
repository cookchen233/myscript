import os
import re
from datetime import datetime

from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class EnumGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""
        self.table_name = ""

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, table_prefix):
        self.table_prefix = table_prefix

    def set_table_name(self, table_name):
        self.table_name = table_name

    def get_template_name(self):
        return "enum.jinja2"

    def _parse_enum_values(self, comment: str) -> list:
        """从注释中解析枚举值"""
        enum_items = []  # 改名为 enum_items
        if '[' in comment and ']' in comment:
            enum_part = comment[comment.find('[') + 1:comment.find(']')]
            for item in enum_part.split(','):
                if ':' in item:
                    key, value = item.strip().split(':')
                    enum_items.append({
                        'key': key.strip(),
                        'value': value.strip(),
                        'constant_name': f'V{key.strip()}'
                    })
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

            if field['Type'].startswith('tinyint') and not field['Field'].startswith('is_'):
                enum_items = self._parse_enum_values(field['Comment'])  # 使用 enum_items
                enum_field = {
                    'field_name': field['Field'],
                    'comment': field['Comment'],
                    'enum_items': enum_items  # 改用 enum_items 作为键名
                }
                enum_fields.append(enum_field)
        
        return enum_fields

    def get_template_variables(self):
        base_name = self.file_name.replace("Enum", "")
        field_name = camel_to_snake(base_name)
        
        # 使用完整的表名
        table_name = self.table_prefix + self.table_name
        
        # 获取所有枚举字段
        enum_fields = self._get_enum_fields(table_name)
        
        # 找到当前处理的枚举字段
        current_enum = None
        for enum in enum_fields:
            if enum['field_name'] == field_name:
                current_enum = enum
                break
                
        if current_enum is None:
            raise ValueError(f"No enum field found for {field_name}")
        
        return {
            'module_name': self.module_name,
            'class_name': self.file_name,
            'enums': [current_enum],
            'datetime': datetime
        }