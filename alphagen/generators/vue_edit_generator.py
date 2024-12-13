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
        comment = field["Comment"]

    # 处理特殊字段名称
        if "enabled" in field_name or "disabled" in field_name or "is_" in field_name:
            return "switch"
        if any(word in field_name for word in ["status", "type", "level", "gender"]):
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

    def _get_data_id_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        data_id_fields = []

        for field in table_schema:
            field_name = field["Field"].lower()
            field_type = self._get_field_base_type(field)
            comment = field["Comment"]
            if field_type == "number" and "[" in comment and "]" in comment:
                try:
                    bracket_content = comment[comment.index("[")+1:comment.index("]")].strip()
                    if ":" in bracket_content:
                        id_part, table_part = bracket_content.split(":")
                        if id_part.strip() == "id":
                            table_part = table_part.strip()
                            data_id_fields.append({
                                "field": field_name,
                                "table_name": table_part,
                                "options_name": f"{table_part}Options",
                                "url": f"/api/{table_part}/list"  # API路径可以根据实际情况调整
                            })
                except:
                    print("get data_id_fields failed")

        return data_id_fields

    def _get_form_fields(self, table_name):
        table_schema = self._get_table_schema(table_name)
        form_fields = []

        exclude_fields = ['id', 'site_id', 'create_time', 'update_time', 'delete_time']

        for field in table_schema:
            if field["Field"] in exclude_fields:
                continue

            field_name = field["Field"].lower()
            field_type = self._get_field_base_type(field)
            form_type = self._get_form_type(field)

            # 检查注释中是否包含关联字段信息
            comment = field["Comment"]
            if field_type == "number" and "[" in comment and "]" in comment:
                try:
                    # 提取方括号中的内容
                    bracket_content = comment[comment.index("[")+1:comment.index("]")].strip()
                    if ":" in bracket_content:
                        # 解析 id:table 格式
                        id_part, table_part = bracket_content.split(":")
                        if id_part.strip() == "id":
                            table_name = table_part.strip()
                            # 修改表单类型为 data-id
                            form_type = "data-id"
                            label = self.clean_comment(comment[:comment.index("[")]).strip()
                            # 修改字段配置
                            field_config = {
                                "field": field_name,
                                "label": label,
                                "required": "NO" in field["Null"],
                                "form_type": form_type,
                                "field_type": field_type,
                                "props": {
                                    "field": f"{table_name}Options",
                                    "class": "w-[320px]",
                                    "placeholder": f"请选择{label}"
                                }
                            }
                            form_fields.append(field_config)
                            continue
                except:
                    pass

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
        data_id_fields = self._get_data_id_fields(table_name)

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
            "data_id_fields": data_id_fields,
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
