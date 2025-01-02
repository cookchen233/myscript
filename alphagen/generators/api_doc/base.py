import os
import re
from datetime import datetime
from jinja2 import Environment, FileSystemLoader

from ..base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class ApiDocBaseGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""

        # 常见的不作为参数的字段
        self.non_param_fields = {
            'content', 'detail', 'description', 'desc', 'remark',
            'deleted_time', 'create_time', 'update_time', 'preview_img',
            'imgs', 'files', 'attachments',
            'site_id',
        }

        # 在返回结果中要排除的字段
        self.exclude_response_fields = {
            'site_id', 'delete_time'
        }

    def generated_file_name(self):
        return f"{self.get_table_comment()}{self.get_doc_type()}.http"

    def get_template_variables(self):
        """获取模板变量"""
        base_name = self.file_name.replace("Model", "")
        table_name = self.table_prefix + camel_to_snake(base_name)

        table_comment = self.get_table_comment()

        table_schema = self._get_table_schema(table_name)
        relations = self._get_model_relations(table_schema)

        display_name = f"{table_comment}{self.get_doc_type()}"

        return dict(
            site_id=self.site_id,
            table_name=table_name,
            table_prefix=self.table_prefix,
            module_name=self.module_name,
            class_name=self.file_name,
            display_name=display_name,
            model_variable_name="$" + snake_to_camel(camel_to_snake(self.file_name)),
            table_comment=table_comment,
            properties=self._get_model_properties(table_schema),
            relations=relations,
            datetime=datetime
        )

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为API参数 - 由子类实现"""
        raise NotImplementedError

    def _get_model_properties(self, table_schema):
        model_properties = []
        for field in table_schema:
            field_type = field["Type"]
            field_name = field["Field"]
            comment = field["Comment"]

            # 如果字段在排除列表中，跳过
            if field_name in self.exclude_response_fields:
                continue

            property_type = self._get_property_type(field_type)
            example_value = self._get_example_value(field_name, field_type, property_type)

            model_property = dict(
                name=snake_to_camel(field_name),
                property_type=property_type,
                field_name=field_name,
                field_comment=comment,
                is_parameter=self._should_be_parameter(field_name, field_type, comment),
                example_value=example_value,
                set_method_name=snake_to_camel("set_" + field_name),
                get_method_name=snake_to_camel("get_" + field_name),
            )
            model_properties.append(model_property)
        return model_properties

    def _get_property_type(self, field_type):
        """获取属性类型"""
        if any(t in field_type.lower() for t in ['int', 'float', 'decimal', 'double', 'tinyint']):
            return "int"
        elif 'datetime' in field_type.lower() or 'timestamp' in field_type.lower():
            return "datetime"
        elif 'date' in field_type.lower():
            return "date"
        elif 'time' in field_type.lower():
            return "time"
        else:
            return "string"

    def _get_example_value(self, field_name, field_type, property_type):
        """获取示例值"""
        # 特殊字段名处理
        if field_name.endswith('_status'):
            return 1
        elif field_name.endswith('_type'):
            return 1
        elif field_name == 'id' or field_name.endswith('_id'):
            return 1
        elif field_name in {'is_deleted', 'is_enabled', 'is_visible', 'is_active'}:
            return 0
        elif 'phone' in field_name:
            return "13800138000"
        elif 'email' in field_name:
            return "example@example.com"
        elif field_name == 'page':
            return 1
        elif field_name == 'page_size':
            return 20

        # 根据类型处理
        if property_type == "int":
            return 0
        elif property_type == "datetime":
            return "2024-01-01 00:00:00"
        elif property_type == "date":
            return "2024-01-01"
        elif property_type == "time":
            return "00:00:00"
        else:
            # 如果字段名包含name或title，返回更有意义的示例值
            if 'name' in field_name or 'title' in field_name:
                return "标题 ..."
            elif 'keyword' in field_name:
                return "关键词"
            elif 'remark' in field_name or 'desc' in field_name:
                return "说明 ..."
            elif 'img' in field_name:
                return "xx.png"
            else:
                return ""

    def _get_model_relations(self, table_schema):
        """获取模型关联关系"""
        relations = []
        for field in table_schema:
            field_name = field["Field"]
            comment = field["Comment"]

            # 检查是否是外键关联字段
            if field_name.endswith("_id") and "[id:" in comment:
                # 从注释中提取关联表名
                match = re.search(r'\[id:(\w+)\]', comment)
                if match:
                    relation_table = self.module_name + "_" + match.group(1)
                    relation_name = field_name.replace("_id", "")

                    # 构建关联配置
                    relation = {
                        "name": relation_name,
                        "type": "belongsTo",
                        "model": snake_to_camel(relation_table, True) + "Model",
                        "foreign_key": field_name,
                        "local_key": "id",
                        "comment": f"关联{camel_to_snake(relation_table)}表"
                    }
                    relations.append(relation)

        return relations


    def _add_file_header(self, content: str) -> str:
        """Add a file header comment."""
        now = datetime.now()
        formatted_date = now.strftime("%B %d, %Y")  # Format: November 29, 2024
        formatted_time = now.strftime("%H:%M:%S")    # Format: 21:07:04

        header = f"""# This file is auto-generated.
# If you delete the tag "@generated ...", this file will not be generated again.
# @generated by AlphaGenerator on {formatted_date}, at {formatted_time}
"""
        return header + content

    def get_doc_type(self):
        """获取文档类型 - 由子类实现"""
        raise NotImplementedError
