# vue_edit_generator.py

import os
import re
from datetime import datetime
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueEditGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""
        self.api_prefix = ""

    def get_template_name(self):
        return "vue_edit.jinja2"

    def _get_form_type(self, field):
        field_type = field["Type"].lower()
        field_name = field["Field"].lower()
        
        # 处理特殊字段名称
        if any(word in field_name for word in ["status", "type", "level"]):
            return "enum-selector"  # 使用枚举选择器组件
        if "area" in field_name or "region" in field_name:
            return "area-selector"  # 使用地区选择器组件
        if "preview_img" in field_name:
            return "select-file-single"  # 单图片上传
        if "imgs" in field_name or "images" in field_name:
            return "select-file-multiple"  # 多图片上传
        if "file" in field_name:
            return "select-file"
        if "time" in field_name or "date" in field_name:
            return "date-picker"
        if "content" in field_name or "desc" in field_name or "remark" in field_name:
            return "textarea"
                
        # 处理字段类型
        if "int" in field_type:
            return "number"
        if "decimal" in field_type or "float" in field_type:
            return "number"
        if "text" in field_type:
            return "textarea"
            
        return "text"

    def _get_search_type(self, field):
        """判断字段是否需要搜索以及搜索类型"""
        field_name = field["Field"].lower()
        field_type = field["Type"].lower()
        
        # 不需要搜索的字段
        exclude_fields = ['id', 'create_time', 'update_time', 'delete_time', 'imgs', 'preview_img']
        if field_name in exclude_fields:
            return None
                
        # 根据字段名判断搜索类型
        if any(word in field_name for word in ["status", "type", "level"]):
            return "select"
        if "time" in field_name or "date" in field_name:
            return "daterange"
        if any(word in field_name for word in ["price", "amount", "money"]):
            return "numberrange" 
        
        # 根据字段类型判断
        if "varchar" in field_type:
            return "text"
        if "int" in field_type or "decimal" in field_type:
            if "status" in field_name or "type" in field_name:
                return "select"
            return "number"
                
        return None

    def _get_enum_fields(self, table_name):
        """获取需要枚举选择器的字段"""
        table_schema = self._get_table_schema(table_name)
        enum_fields = []
        
        for field in table_schema:
            field_name = field["Field"].lower()
            if any(word in field_name for word in ["status", "type", "level"]):
                # 转换字段名为枚举名称
                enum_name = snake_to_camel(field_name)  # 驼峰形式
                options_name = enum_name + "s"  # 选项数组名称
                enum_fields.append({
                    "field": field_name,
                    "enum_name": enum_name,  # 变量名
                    "options_name": options_name,  # 选项数组名
                    "comment": field["Comment"]
                })
        
        return enum_fields


    def _get_form_fields(self, table_name):
        """获取表单字段配置"""
        table_schema = self._get_table_schema(table_name)
        form_fields = []
        
        exclude_fields = ['id', 'create_time', 'update_time', 'delete_time']
        
        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue
                    
            field_name = field["Field"].lower()
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
                "required": "NO" in field["Null"],
                "prop": snake_to_camel(field_name)
            }
            
            # 特殊字段处理
            if "area" in field_name:
                field_config["type"] = "area-selector"
                
            elif "status" in field_name or "type" in field_name or "level" in field_name:
                field_config["type"] = "enum"
                field_config["disabled"] = "!!formData.source_id"
                field_config["readonly"] = "!!formData.source_id"
                
            elif "price" in field_name:
                field_config["type"] = "number"
                field_config["precision"] = 2
                field_config["step"] = 10
                field_config["min"] = 0
                
            elif "preview_img" in field_name:
                field_config["type"] = "select-file"
                field_config["file_type"] = "image"
                
            elif "imgs" in field_name:
                field_config["type"] = "select-file"
                field_config["file_type"] = "image"
                field_config["multiple"] = True
                field_config["limit"] = 15
                
            elif "facilities" in field_name:
                field_config["type"] = "checkbox-group"
                field_config["options"] = "facilities"
                
            elif "description" in field_name:
                field_config["type"] = "textarea"
                field_config["rows"] = 4
                field_config["width"] = 420
                
            elif field_name in ["max_guests", "total_rooms"]:
                field_config["type"] = "number"
                field_config["min"] = 1
                field_config["width"] = 320
                field_config["disabled"] = "!!formData.source_id" if field_name == "total_rooms" else None
                
            else:
                field_config["type"] = "text"
                field_config["width"] = 320
                
            form_fields.append(field_config)
                
        return form_fields

    def _get_table_fields(self, table_name):
        """获取表格列配置"""
        table_schema = self._get_table_schema(table_name)
        table_fields = []
        
        # 添加 ID 列
        table_fields.append({
            "field": "id",
            "label": "ID",
            "width": 80,
            "align": "center"
        })
        
        for field in table_schema:
            if field["Field"] == "id" or field["Field"] == "delete_time":
                continue
                
            field_name = field["Field"].lower()
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
                "prop": snake_to_camel(field_name)
            }
            
            # 设置特殊列配置
            if "price" in field_name:
                field_config["type"] = "money"
                field_config["width"] = 120
            elif "time" in field_name:
                field_config["type"] = "datetime"
                field_config["width"] = 180
            elif any(word in field_name for word in ["status", "type", "level"]):
                field_config["type"] = "enum"
                field_config["width"] = 100
            elif "preview_img" in field_name:
                field_config["type"] = "image"
                field_config["width"] = 120
            elif field_name in ["max_guests", "total_rooms"]:
                field_config["width"] = 100
                
            table_fields.append(field_config)
        
        return table_fields

    def _get_search_fields(self, table_name):
        """获取搜索字段配置"""
        search_fields = []
        
        # 添加关键字搜索
        search_fields.append({
            "field": "keywords",
            "label": "搜索",
            "type": "text",
            "width": 420,
            "placeholder": "请输入关键字"
        })
        
        # 选择器类型字段
        enum_types = ["status", "type", "level"]
        # 数字范围类型字段
        range_types = ["price", "amount"]
        # 日期范围类型字段 
        date_types = ["time", "date"]
        
        for field in self._get_table_schema(table_name):
            field_name = field["Field"].lower()
            
            # 跳过不需要搜索的字段
            if field_name in ['id', 'create_time', 'update_time', 'delete_time', 
                            'preview_img', 'imgs', 'description', 'url']:
                continue
                
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
            }
            
            # 根据字段名称判断类型
            if any(t in field_name for t in enum_types):
                field_config["type"] = "enum" 
                field_config["width"] = 200
                
            elif any(t in field_name for t in range_types):
                field_config["type"] = "numberrange"
                field_config["start_field"] = f"{field_name}_min"
                field_config["end_field"] = f"{field_name}_max"
                field_config["min"] = 0
                
            elif any(t in field_name for t in date_types):
                field_config["type"] = "daterange"
                field_config["start_field"] = f"{field_name}_start"
                field_config["end_field"] = f"{field_name}_end"
                field_config["model"] = f"{field_name}Range"
                
            elif field_name == "max_guests":
                field_config["type"] = "number"
                field_config["min"] = 1
                field_config["width"] = 120
                
            else:
                continue
                
            search_fields.append(field_config)
                
        return search_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)
        
        # 获取字段配置
        table_schema = self._get_table_schema(table_name)
        form_fields = self._get_form_fields(table_name)
        table_fields = self._get_table_fields(table_name)
        search_fields = self._get_search_fields(table_name)
        enum_fields = self._get_enum_fields(table_name)
        
        # 检查特殊功能
        has_area = any(f["type"] == "area-selector" for f in form_fields)
        has_image = any(f["type"] in ["select-file-single", "select-file-multiple"] for f in form_fields)
        has_delete = "delete_time" in [f["Field"] for f in table_schema]
        
        return {
            "module_name": self.module_name,
            "class_name": base_name,
            "table_name": table_name,
            "table_comment": self._get_table_status(table_name, "Comment"),
            "form_fields": form_fields,
            "table_fields": table_fields,
            "search_fields": search_fields,
            "enum_fields": enum_fields,
            "has_area": has_area,
            "has_image": has_image,
            "has_delete": has_delete,
            "datetime": datetime
        }
    
    def _has_image_upload(self, table_name):
        """判断是否有图片上传字段"""
        for field in self._get_table_schema(table_name):
            if "image" in field["Field"].lower() or "img" in field["Field"].lower():
                return True
        return False

    def _has_area_selector(self, table_name):
        """判断是否有地区选择器"""
        for field in self._get_table_schema(table_name):
            if "area" in field["Field"].lower() or "region" in field["Field"].lower():
                return True
        return False

    def generate(self):
    rendered = self.render()import os
import re
from datetime import datetime
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueEditGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""
        self.api_prefix = ""

    def get_template_name(self):
        return "vue_edit.jinja2"

    def _get_form_type(self, field):
        field_type = field["Type"].lower()
        field_name = field["Field"].lower()
        
        # 处理特殊字段名称
        if any(word in field_name for word in ["status", "type", "level"]):
            return "enum-selector"
        if "area" in field_name or "region" in field_name:
            return "area-selector"
        if "preview_img" in field_name:
            return "select-file-single"
        if "imgs" in field_name or "images" in field_name:
            return "select-file-multiple"
        if "file" in field_name:
            return "select-file"
        if "time" in field_name or "date" in field_name:
            return "date-picker"
        if "content" in field_name or "desc" in field_name or "remark" in field_name:
            return "textarea"
                
        # 处理字段类型
        if "int" in field_type:
            return "number"
        if "decimal" in field_type or "float" in field_type:
            return "number"
        if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
            return "textarea"
        if "varchar" in field_type or "char" in field_type:
            return "text"
            
        return "text"

    def _get_search_type(self, field):
        field_name = field["Field"].lower()
        field_type = field["Type"].lower()
        
        # 不需要搜索的字段
        exclude_fields = ['id', 'create_time', 'update_time', 'delete_time', 'imgs', 'preview_img']
        if field_name in exclude_fields:
            return None
                
        # 根据字段名判断搜索类型
        if any(word in field_name for word in ["status", "type", "level"]):
            return "select"
        if "time" in field_name or "date" in field_name:
            return "daterange"
        if any(word in field_name for word in ["price", "amount", "money"]):
            return "numberrange"
        
        # 根据字段类型判断
        if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
            return None  # 长文本字段不支持搜索
        if "varchar" in field_type or "char" in field_type:
            return "text"
        if "int" in field_type or "decimal" in field_type:
            if "status" in field_name or "type" in field_name:
                return "select"
            return "number"
                
        return None

    def _get_enum_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        enum_fields = []
        
        for field in table_schema:
            field_name = field["Field"].lower()
            if any(word in field_name for word in ["status", "type", "level"]):
                enum_name = snake_to_camel(field_name)
                options_name = enum_name + "s"
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
        
        exclude_fields = ['id', 'create_time', 'update_time', 'delete_time']
        
        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue
                    
            field_name = field["Field"].lower()
            field_type = field["Type"].lower()
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
                "required": "NO" in field["Null"],
                "prop": snake_to_camel(field_name)
            }
            
            # 特殊字段处理
            if "area" in field_name:
                field_config["type"] = "area-selector"
                
            elif "status" in field_name or "type" in field_name or "level" in field_name:
                field_config["type"] = "enum"
                field_config["disabled"] = "!!formData.source_id"
                field_config["readonly"] = "!!formData.source_id"
                
            elif "price" in field_name:
                field_config["type"] = "number"
                field_config["precision"] = 2
                field_config["step"] = 10
                field_config["min"] = 0
                
            elif "preview_img" in field_name:
                field_config["type"] = "select-file"
                field_config["file_type"] = "image"
                
            elif "imgs" in field_name:
                field_config["type"] = "select-file"
                field_config["file_type"] = "image"
                field_config["multiple"] = True
                field_config["limit"] = 15
                
            elif "facilities" in field_name:
                field_config["type"] = "checkbox-group"
                field_config["options"] = "facilities"
                
            elif "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
                field_config["type"] = "textarea"
                field_config["rows"] = 4
                field_config["width"] = 420
                
            elif field_name in ["max_guests", "total_rooms"]:
                field_config["type"] = "number"
                field_config["min"] = 1
                field_config["width"] = 320
                field_config["disabled"] = "!!formData.source_id" if field_name == "total_rooms" else None
                
            else:
                field_config["type"] = "text"
                field_config["width"] = 320
                
            form_fields.append(field_config)
                
        return form_fields

    def _get_table_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        table_fields = []
        
        table_fields.append({
            "field": "id",
            "label": "ID",
            "width": 80,
            "align": "center"
        })
        
        for field in table_schema:
            if field["Field"] == "id" or field["Field"] == "delete_time":
                continue
                
            field_name = field["Field"].lower()
            field_type = field["Type"].lower()
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
                "prop": snake_to_camel(field_name)
            }
            
            if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
                field_config["type"] = "text"
                field_config["width"] = 180
                field_config["show_overflow_tooltip"] = True
            elif "price" in field_name:
                field_config["type"] = "money"
                field_config["width"] = 120
            elif "time" in field_name:
                field_config["type"] = "datetime"
                field_config["width"] = 180
            elif any(word in field_name for word in ["status", "type", "level"]):
                field_config["type"] = "enum"
                field_config["width"] = 100
            elif "preview_img" in field_name:
                field_config["type"] = "image"
                field_config["width"] = 120
            elif field_name in ["max_guests", "total_rooms"]:
                field_config["width"] = 100
                
            table_fields.append(field_config)
        
        return table_fields

    def _get_search_fields(self, table_name):
        search_fields = []
        
        search_fields.append({
            "field": "keywords",
            "label": "搜索",
            "type": "text",
            "width": 420,
            "placeholder": "请输入关键字"
        })
        
        enum_types = ["status", "type", "level"]
        range_types = ["price", "amount"]
        date_types = ["time", "date"]
        
        for field in self._get_table_schema(table_name):
            field_name = field["Field"].lower()
            field_type = field["Type"].lower()
            
            # 跳过不需要搜索的字段
            if field_name in ['id', 'create_time', 'update_time', 'delete_time', 
                            'preview_img', 'imgs', 'description', 'url']:
                continue
            
            # 跳过长文本字段    
            if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
                continue
                
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
            }
            
            if any(t in field_name for t in enum_types):
                field_config["type"] = "enum" 
                field_config["width"] = 200
                
            elif any(t in field_name for t in range_types):
                field_config["type"] = "numberrange"
                field_config["start_field"] = f"{field_name}_min"
                field_config["end_field"] = f"{field_name}_max"
                field_config["min"] = 0
                
            elif any(t in field_name for t in date_types):
                field_config["type"] = "daterange"
                field_config["start_field"] = f"{field_name}_start"
                field_config["end_field"] = f"{field_name}_end"
                field_config["model"] = f"{field_name}Range"
                
            elif field_name == "max_guests":
                field_config["type"] = "number"
                field_config["min"] = 1
                field_config["width"] = 120
                
            else:
                continue
                
            search_fields.append(field_config)
                
        return search_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)
        
        table_schema = self._get_table_schema(table_name)
        form_fields = self._get_form_fields(table_name)
        table_fields = self._get_table_fields(table_name)
        search_fields = self._get_search_fields(table_name)
        enum_fields = self._get_enum_fields(table_name)
        
        has_area = any(f["type"] == "area-selector" for f in form_fields)
        has_image = any(f["type"] in ["select-file-single", "select-file-multiple"] for f in form_fields)
        has_delete = "delete_time" in [f["Field"] for f in table_schema]
        
        return {
            "module_name": self.module_name,
            "class_name": base_name,
            "table_name": table_name,
            "table_comment": self._get_table_status(table_name, "Comment"),
            "form_fields": form_fields,
            "table_fields": table_fields,
            "search_fields": search_fields,
            "enum_fields": enum_fields,
            "has_area": has_area,
            "has_image": has_image,
            "has_delete": has_delete,
            "datetime": datetime
        }
    
    def _has_image_upload(self, table_name):
        for field in self._get_table_schema(table_name):
            if "image" in field["Field"].lower() or "img" in field["Field"].lower():
                return True
        return False

    def _has_area_selector(self, table_name):
        for field in self._get_table_schema(table_name):
            if "area" in field["Field"].lower() or "region" in field["Field"].lower():
                return True
        return False

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
        
        if os.path.exists(filename):
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

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_api_prefix(self, api_prefix):
        self.api_prefix = api_prefix

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix