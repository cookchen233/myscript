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