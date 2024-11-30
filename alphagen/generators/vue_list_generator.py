from datetime import datetime
import os
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueListGenerator(BaseGenerator):
    def get_template_name(self):
        return "vue_list.jinja2"

    def _get_column_type(self, field):
        """
        判断表格列的类型
        """
        field_name = field["Field"].lower()
        field_type = field["Type"].lower()
        
        if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
            return "text"
        if "price" in field_name or "amount" in field_name:
            return "money"
        # if "time" in field_name or "date" in field_name:
            # return "datetime"
        if any(word in field_name for word in ["status", "type", "level"]):
            return "enum"
        if "img" in field_name or "imgs" in field_name or "images" in field_name:
            return "image"
        # switch类型只处理 tinyint 且是启用/禁用相关字段
        if ("enabled" in field_name or "disabled" in field_name or field_name.startswith("is_")) and "tinyint" in field_type:
            return "switch"
                
        return None

    def _get_search_type(self, field):
        """
        判断搜索字段的类型
        """
        field_name = field["Field"].lower()
        field_type = field["Type"].lower()
        
        # 不需要搜索的字段
        exclude_fields = [
            'id', 'site_id', 
            'create_time', 
            'update_time', 'delete_time',
            'preview_img', 'imgs', 'images', 'description', 'url', 'content', 'remark'
        ]
        if field_name in exclude_fields:
            return None
            
        # 跳过长文本字段    
        if "text" in field_type or "mediumtext" in field_type or "longtext" in field_type:
            return None
            
        if any(word in field_name for word in ["status", "type", "level"]):
            return "enum"
        if any(word in field_name for word in ["price", "amount"]):
            return "numberrange"
        if "time" in field_name or "date" in field_name:
            return "daterange"
        # switch类型字段在搜索时也使用0/1选择
        if ("enabled" in field_name or "disabled" in field_name or field_name.startswith("is_")) and "tinyint" in field_type:
            return "switch"
        if field_name in ["max_guests", "total_rooms"]:
            return "number"
            
        return None

    def _get_enum_fields(self, table_name):
        """
        获取枚举字段（不包含switch类型）
        """
        table_schema = self._get_table_schema(table_name)
        enum_fields = []
        
        for field in table_schema:
            field_name = field["Field"].lower()
            column_type = self._get_column_type(field)
            
            # 只处理enum类型，不包含switch
            if column_type == "enum":
                enum_name = snake_to_camel(field_name)
                options_name = enum_name + "Options"
                enum_fields.append({
                    "field": field_name,
                    "enum_name": enum_name,
                    "options_name": options_name,
                    "comment": field["Comment"]
                })
        
        return enum_fields
    
    def _get_table_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        table_fields = []
        
        # 添加ID列
        table_fields.append({
            "field": "id",
            "label": "ID",
            "width": 80,
            "align": "center"
        })


        # 不需要展示的字段
        exclude_fields = [
            'site_id', 
            'create_time', 
            'update_time', 'delete_time',
            'imgs', 'images', 'description', 'url', 'content', 'remark'
        ]
        
        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue
            if field["Field"] == "id" or field["Field"] == "delete_time":
                continue
                
            field_name = field["Field"].lower()
            column_type = self._get_column_type(field)
            
            field_config = {
                "field": field_name,
                "label": self.clean_comment(field["Comment"]) or field_name,
                "prop": snake_to_camel(field_name)
            }
            
            # 根据类型设置特定配置
            if column_type:
                field_config["type"] = column_type
                
                if column_type == "text":
                    field_config.update({
                        "width": 180,
                        "show_overflow_tooltip": True
                    })
                elif column_type == "money":
                    field_config["width"] = 120
                elif column_type == "datetime":
                    field_config["width"] = 180
                elif column_type in ["enum", "switch"]:
                    field_config["width"] = 100
                elif column_type == "image":
                    field_config["width"] = 120
            elif field_name in ["max_guests", "total_rooms"]:
                field_config["width"] = 100
                
            table_fields.append(field_config)
        
        return table_fields

    def _get_search_fields(self, table_name):
        search_fields = []
        
        # 添加关键字搜索
        # search_fields.append({
        #     "field": "keywords",
        #     "label": "搜索",
        #     "type": "text",
        #     "width": 420,
        #     "placeholder": "请输入关键字"
        # })
        
        for field in self._get_table_schema(table_name):
            field_name = field["Field"].lower()
            search_type = self._get_search_type(field)
            
            if not search_type:
                continue
                
            field_config = {
                "field": field_name,
                "label": self.clean_comment(field["Comment"]) or field_name,
                "type": search_type
            }
            
            # 简单配置
            if search_type == "enum":
                field_config["width"] = 200
            elif search_type == "numberrange":
                field_config.update({
                    "min": 0,
                    "precision": 2 if "price" in field_name else 0
                })
            elif search_type == "number":
                field_config.update({
                    "min": 1,
                    "width": 120
                })
                
            search_fields.append(field_config)
                
        return search_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)
        
        table_schema = self._get_table_schema(table_name)
        table_fields = self._get_table_fields(table_name)
        search_fields = self._get_search_fields(table_name)
        enum_fields = self._get_enum_fields(table_name)
        
        has_delete = "delete_time" in [f["Field"] for f in table_schema]
        
        return {
            "module_name": self.module_name,
            "class_name": base_name,
            "table_name": table_name,
            "table_comment": self._get_table_status(table_name, "Comment"),
            "table_fields": table_fields,
            "search_fields": search_fields,
            "enum_fields": enum_fields,
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
        filename = os.path.join(file_dir, "list.vue")
        
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