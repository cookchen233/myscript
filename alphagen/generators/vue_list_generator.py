# vue_list_generator.py
from datetime import datetime
import os
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class VueListGenerator(BaseGenerator):
    def get_template_name(self):
        return "vue_list.jinja2"

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
            'id',
            'site_id','create_time','update_time', 'delete_time',
            'imgs', 'images', 'description', 'url', 'content', 'remark'
        ]

        for field in table_schema:
            field_name = field["Field"].lower()
            display_type = self._get_field_display_type(field)
            base_type = self._get_field_base_type(field)
            if field_name in exclude_fields:
                continue
            if base_type == "longtext":
                continue

            field_config = {
                "field": field_name,
                "label": self.clean_comment(field["Comment"]) or field_name,
                "prop": snake_to_camel(field_name),
                "display_type": display_type,
                "base_type": base_type,
                "template": False,
            }

            # 根据类型设置特定配置
            type_configs = {
                "datetime": {
                    "width": 180
                },
                "enum": {
                    "width": 100,
                    "template": True
                },
                "switch": {
                    "width": 100,
                    "template": True
                },
                "data-id": {
                    "width": 100,
                    "template": True
                },
                "image": {
                    "width": 120,
                    "template": True,
                    "align": "center"
                },
                "file": {
                    "width": 120,
                    "template": True,
                    "align": "center"
                }
            }

            if display_type in type_configs:
                field_config.update(type_configs[display_type])
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
            display_type = self._get_field_display_type(field)
            base_type = self._get_field_base_type(field)
            comment = field["Comment"]

            # 不需要搜索的字段
            exclude_fields = [
                'id', 'site_id',
                'member_id',
                'create_time',
                'update_time', 'delete_time',
                'preview_img', 'preview_image', 'main_image', 'imgs', 'images', 'description', 'url', 'content', 'remark'
            ]
            if field_name in exclude_fields:
                continue

            if base_type == "longtext":
                continue

            # 设置搜索类型
            search_type = display_type

            if display_type == "datetime":
                search_type = "daterange"

            if "_id" not in field_name and display_type == "text":
                continue

            field_config = {
                "field": field_name,
                "label": self.clean_comment(comment) or field_name,
                "search_type": search_type
            }

            # 根据不同的搜索类型设置配置
            search_type_config = {
                "enum": {
                    "width": 200,
                    "clearable": True
                },
                "numberrange": {
                    "min": 0,
                    "precision": 2 if "price" in field_name else 0
                },
                "number": {
                    "min": 1,
                    "width": 120
                }
            }

            # 如果存在对应的配置则更新
            if search_type in search_type_config:
                field_config.update(search_type_config[search_type])

            search_fields.append(field_config)

        return search_fields

    def get_template_variables(self):
        base_name = self.file_name
        table_name = self.table_prefix + camel_to_snake(base_name)

        table_schema = self._get_table_schema(table_name)
        table_fields = self._get_table_fields(table_name)
        search_fields = self._get_search_fields(table_name)

        has_delete = "delete_time" in [f["Field"] for f in table_schema]

        # 获取批量操作按钮配置
        batch_buttons = self._get_batch_buttons(table_schema)

        return {
            "module_name": self.module_name,
            "class_name": base_name,
            "table_name": table_name,
            "table_comment": self.get_table_comment(),
            "table_fields": table_fields,
            "search_fields": search_fields,
            "has_delete": has_delete,
            "batch_buttons": batch_buttons,
            "datetime": datetime
        }

    def _get_batch_buttons(self, table_schema):
        """获取批量操作按钮配置"""
        buttons = []

        # 检查是否有 is_enabled 字段
        if any(f["Field"] == "is_enabled" for f in table_schema):
            buttons.append({
                "text": "批量启用",
                "type": "primary",
                "update_data": {"is_enabled": 1},
                "confirm_message": "确定要批量启用选中的记录吗？"
            })
            buttons.append({
                "text": "批量禁用",
                "type": "warning",
                "update_data": {"is_enabled": 0},
                "confirm_message": "确定要批量禁用选中的记录吗？"
            })

        return buttons

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
