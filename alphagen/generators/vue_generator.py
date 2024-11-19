# vue_generator.py

import os
import re
from datetime import datetime
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""
        self.api_prefix = ""

    def get_template_name(self):
        return "vue.jinja2"

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
                
            form_type = self._get_form_type(field)
            field_config = {
                "field": field["Field"],
                "label": field["Comment"] or field["Field"],
                "type": form_type,
                "required": "NO" in field["Null"],
                "prop": snake_to_camel(field["Field"])
            }
            
            # 针对不同类型添加特殊配置
            if form_type == "number":
                field_config["min"] = 0
                if "unsigned" in field["Type"]:
                    field_config["min"] = 0
                    
            elif form_type == "select":
                field_config["options"] = []
                
            form_fields.append(field_config)
            
        return form_fields

    def _get_table_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        table_fields = []
        
        # 需要排除的字段
        exclude_fields = ['delete_time']
        
        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue
                
            field_name = field["Field"].lower()
            field_config = {
                "field": field_name,
                "label": field["Comment"] or field_name,
                "prop": snake_to_camel(field_name),
                "show_overflow_tooltip": True
            }
                
            # 设置特殊列的渲染方式
            if any(word in field_name for word in ["status", "type", "level"]):
                field_config["type"] = "enum"
            elif "preview_img" in field_name or "img" in field_name:
                field_config["type"] = "image"
            elif "price" in field_name or "amount" in field_name:
                field_config["type"] = "money"
            elif "time" in field_name or "date" in field_name:
                field_config["type"] = "datetime"
                
            table_fields.append(field_config)
        
        return table_fields

    def _get_search_fields(self, table_name):
        """获取搜索字段配置"""
        table_schema = self._get_table_schema(table_name)
        search_fields = []
        
        for field in table_schema:
            search_type = self._get_search_type(field)
            if not search_type:
                continue
                
            field_config = {
                "field": field["Field"],
                "label": field["Comment"] or field["Field"],
                "type": search_type,
                "prop": snake_to_camel(field["Field"])
            }
            
            # 针对不同搜索类型添加特殊配置
            if search_type == "select":
                field_config["options"] = []
            elif search_type in ["daterange", "numberrange"]:
                field_config["start_field"] = f"{field['Field']}_start"
                field_config["end_field"] = f"{field['Field']}_end"
                
            search_fields.append(field_config)
            
        return search_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)
        
        # 转换API路径格式
        module_prefix = f"{self.module_name}." if self.module_name else ""
        class_name = base_name
        
        return {
            "module_name": self.module_name,
            "class_name": class_name,
            "table_name": table_name,
            "table_comment": self._get_table_status(table_name, "Comment"),
            "form_fields": self._get_form_fields(table_name),
            "table_fields": self._get_table_fields(table_name),
            "search_fields": self._get_search_fields(table_name),
            "enum_fields": self._get_enum_fields(table_name),
            "has_restore": "delete_time" in [f["Field"] for f in self._get_table_schema(table_name)],
            "has_sort": True,  # 是否支持排序
            "dialog_width": "60%",  # 弹窗宽度
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
        rendered = self.render()
        
        # 转换路径格式
        module_path = self.module_name.lower()
        
        # 去掉表名中的模块前缀(如bb_)并转换为中划线格式
        page_name = camel_to_snake(self.file_name)
        if module_path:
            # 如果存在模块名，移除表名中的模块前缀
            prefix = f"{module_path}_"
            if page_name.startswith(prefix):
                page_name = page_name[len(prefix):]
        
        # 将下划线转换为中划线
        page_path = page_name.replace('_', '-')
        
        # 组合最终路径
        file_dir = os.path.join(self.rendered_file_dir, module_path, page_path)
        filename = os.path.join(file_dir, "index.vue")
        
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