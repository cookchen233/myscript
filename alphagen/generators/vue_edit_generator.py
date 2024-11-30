# vue_edit_generator.py
from datetime import datetime
import os
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueEditGenerator(BaseGenerator):
    def get_template_name(self):
        return "vue_edit.jinja2"

    def _get_form_type(self, field):
        form_type = field["Type"].lower()
        field_name = field["Field"].lower()
        
        # 处理特殊字段名称
        if "enabled" in field_name or "disabled" in field_name or "is_" in field_name:
            return "switch"
        if any(word in field_name for word in ["status", "type", "level"]):
            return "enum"
        if "area" in field_name or "region" in field_name:
            return "area-selector"
        if "img" in field_name:
            return "select-image"
        if "imgs" in field_name or "images" in field_name:
            return "select-image"
        if "file" in field_name:
            return "select-file"
        if "time" in field_name or "time" in form_type:
            return "date-picker"
        if "date" in field_name or "date" in form_type:
            return "date-picker"
        if "content" in field_name or "desc" in field_name or "remark" in field_name:
            return "textarea"
                
        # 处理字段类型
        if "tinyint" in form_type and ("is_" in field_name or "enabled" in field_name):
            return "switch"
        if "int" in form_type:
            return "number"
        if "decimal" in form_type or "float" in form_type:
            return "number"
        if "text" in form_type or "mediumtext" in form_type or "longtext" in form_type:
            return "textarea"
        if "varchar" in form_type or "char" in form_type:
            return "text"
            
        return "text"
        
    def _get_field_type(self, field):
        """
        获取字段的基础数据类型
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

    def _get_enum_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        enum_fields = []
        
        for field in table_schema:
            field_name = field["Field"].lower()
            form_type = self._get_form_type(field)
            if form_type == "enum":
                enum_name = snake_to_camel(field_name)
                options_name = enum_name + "Options"
                enum_fields.append({
                    "field": field_name,
                    "enum_name": enum_name,
                    "options_name": options_name,
                    "comment": field["Comment"]
                })
        
        return enum_fields

    def _get_form_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        form_fields = []
        
        exclude_fields = ['id', 'site_id', 'create_time', 'update_time', 'delete_time']
        
        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue
                    
            field_name = field["Field"].lower()
            field_type = self._get_field_type(field)
            form_type = self._get_form_type(field)
            
            field_config = {
                "field": field_name,
                "label": self.clean_comment(field["Comment"]) or field_name,
                "required": "NO" in field["Null"],
                "prop": snake_to_camel(field_name),
                "form_type": form_type,
                "field_type": field_type,
            }
            
            # 配置属性
            props = {
                "placeholder": f"请{'选择' if form_type in ['enum', 'select', 'area-selector'] else '输入'}{field_config['label']}",
                "class": f"w-[{420 if form_type == 'textarea' else 320}px]"
            }
            
            # 特殊字段处理
            if form_type == "area-selector":
                props.update({
                    "startLevel": 2,
                    "endLevel": 4,
                    "parentCode": "440000000000"
                })
                
            elif form_type == "enum":
                props.update({
                    "field": f"{snake_to_camel(field_name)}Options",
                    "clearable": True
                })
                
            elif form_type == "switch":
                props.update({
                    "activeValue": 1,
                    "inactiveValue": 0,
                    "activeText": "启用",
                    "inactiveText": "禁用"
                })
                
            elif form_type == "number":
                if "price" in field_name:
                    props.update({
                        "precision": 2,
                        "step": 10,
                        "min": 0
                    })
                elif field_name in ["max_guests", "total_rooms"]:
                    props.update({
                        "min": 1,
                        "disabled": "!!formData.source_id" if field_name == "total_rooms" else None
                    })
                
            elif form_type == "select-image":
                props.update({
                    "type": "image",
                    "multiple": "imgs" in field_name or "images" in field_name,
                    "limit": 15 if "imgs" in field_name or "images" in field_name else 1
                })
                
            elif form_type == "select-file":
                props.update({
                    "type": "image",
                    "multiple": "imgs" in field_name or "images" in field_name,
                    "limit": 15 if "imgs" in field_name or "images" in field_name else 1
                })
                
            elif form_type == "textarea":
                props.update({
                    "rows": 4,
                    "maxlength": 500,
                    "showWordLimit": True
                })
                
            field_config["props"] = props
            form_fields.append(field_config)
                
        return form_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)
        
        table_schema = self._get_table_schema(table_name)
        form_fields = self._get_form_fields(table_name)
        enum_fields = self._get_enum_fields(table_name)
        
        has_area = any(f["form_type"] == "area-selector" for f in form_fields)
        has_image = any(f["form_type"] == "image" for f in form_fields) or any(f["form_type"] == "file" for f in form_fields)
        has_delete = "delete_time" in [f["Field"] for f in table_schema]
        
        return {
            "module_name": self.module_name,
            "class_name": base_name,
            "table_name": table_name,
            "table_comment": self._get_table_status(table_name, "Comment"),
            "form_fields": form_fields,
            "enum_fields": enum_fields,
            "has_area": has_area,
            "has_image": has_image,
            "has_delete": has_delete,
            "datetime": datetime
        }

    def generate(self):
        rendered = self.render()
        
        module_path = self.module_name.lower()
        
        page_name = camel_to_snake(self.file_name)
        if module_path:
            prefix = f"{module_path}_"
            if page_name.startswith(prefix):
                page_name = page_name[len(prefix):]
        
        page_path = page_name.replace('_', '-')
        
        file_dir = os.path.join(self.rendered_file_dir, module_path, page_path)
        filename = os.path.join(file_dir, "edit.vue")
        
        if not self.force and os.path.exists(filename):
            print(f'File already exists, skipping: {filename}')
            return
            
        os.makedirs(file_dir, exist_ok=True)
        
        with open(filename, "w", encoding='utf-8') as f:
            f.write(rendered)
            print(f'Successfully generated: {filename}')

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_api_prefix(self, api_prefix):
        self.api_prefix = api_prefix

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix