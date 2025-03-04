import os
import re
from datetime import datetime

from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class ModelGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""

    def get_template_name(self):
        return "table_model.jinja2"

    def get_template_variables(self):
        base_name = self.file_name.replace("Model", "")
        table_name = self.table_prefix + camel_to_snake(base_name)

        table_schema = self._get_table_schema(table_name)
        relations = self._get_model_relations(table_schema)

        return dict(
            table_name=table_name,
            table_prefix=self.table_prefix,
            module_name=self.module_name,
            class_name=self.file_name,
            model_variable_name="$" + snake_to_camel(camel_to_snake(self.file_name)),
            table_comment=self._get_table_status(table_name, "Comment"),
            properties=self._get_model_properties(table_schema),
            json_fields=self.get_json_fields(table_schema),
            enum_fields=self._get_enum_fields(table_name),
            relations=relations,
            datetime=datetime
        )

    def get_json_fields(self, table_schema):
        """获取JSON类型字段列表"""
        json_fields = []
        for field in table_schema:
            field_comment = field["Comment"].upper()
            if "[JSON]" in field_comment or field_comment.endswith("JSON"):
                json_fields.append(field["Field"])
        return json_fields

    def _get_model_properties(self, table_schema):
        model_properties = []
        for field in table_schema:
            if 'int' in field["Type"] or 'float' in field["Type"] or 'decimal' in field["Type"]:
                property_type = "int"
            else:
                property_type = "string"
            model_property = dict(
                name=snake_to_camel(field["Field"]),
                property_type=property_type,
                field_name=field["Field"],
                field_comment=field["Comment"],
                set_method_name=snake_to_camel("set_" + field["Field"]),
                get_method_name=snake_to_camel("get_" + field["Field"]),
            )
            model_properties.append(model_property)
        return model_properties

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
                    local_key = "id"
                    if relation_name == "member":
                        relation_model = "\\app\\common\\model\\Member"
                        local_key = "member_id"
                        continue
                    elif relation_name == "admin":
                        relation_model = "\\app\\common\\model\\AdminUser"
                        local_key = "admin_id"
                        continue
                    elif relation_name == "audit_admin":
                        relation_model = "\\app\\common\\model\\AdminUser"
                        local_key = "admin_id"
                        continue
                    elif relation_name == "order":
                        relation_model = "\\app\\common\\model\\ec\\EcOrderModel"
                        local_key = "id"
                        relation_name = "ec_order"
                    else:
                        relation_model = snake_to_camel(relation_table, True) + "Model"

                    relation = {
                        "name": relation_name,
                        "type": "belongsTo",
                        "model": relation_model,
                        "foreign_key": field_name,
                        "local_key": local_key,
                        "comment": f"关联{camel_to_snake(relation_table)}表"
                    }
                    relations.append(relation)

        return relations

    def generate(self):
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        rendered = self.render()
        filename = os.path.join(self.rendered_file_dir, self.file_name + ".php")

        # 确保目录存在
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        if os.path.exists(filename):
            # 读取现有文件内容
            with open(filename, 'r', encoding='utf-8') as f:
                existing_content = f.read()

            # 提取现有属性
            properties_start_marker = "<!-- BEGIN PROPERTIES -->"
            properties_end_marker = "<!-- END PROPERTIES -->"

            # 从新渲染的内容中提取新属性
            new_properties_start = rendered.find(properties_start_marker)
            new_properties_end = rendered.find(properties_end_marker) + len(properties_end_marker)
            new_properties = rendered[new_properties_start:new_properties_end] if new_properties_start != -1 else ""

            # 从现有文件中提取旧属性
            existing_properties_start = existing_content.find(properties_start_marker)
            existing_properties_end = existing_content.find(properties_end_marker) + len(properties_end_marker)
            existing_properties = existing_content[existing_properties_start:existing_properties_end] if existing_properties_start != -1 else ""

            # 比较属性是否发生变化（忽略空格和换行的差异）
            def normalize_properties(props):
                return ' '.join(props.split())

            if normalize_properties(new_properties) != normalize_properties(existing_properties):
                # 属性发生变化，更新文件
                if existing_properties_start != -1 and existing_properties_end != -1:
                    # 获取原始生成时间
                    generated_time = None
                    generated_match = re.search(r'@generated\s+([\d-]+\s+[\d:]+)', existing_content)
                    if generated_match:
                        generated_time = generated_match.group(1)

                    # 更新属性和时间戳
                    updated_content = (
                            existing_content[:existing_properties_start] +
                            new_properties +
                            existing_content[existing_properties_end:]
                    )

                    # 更新时间戳
                    if generated_time:
                        # 保留原始生成时间，更新更新时间
                        updated_content = re.sub(
                            r'(@generated\s+)([\d-]+\s+[\d:]+)',
                            f'@generated {generated_time}',
                            updated_content
                        )
                        updated_content = re.sub(
                            r'(@updated\s+)([\d-]+\s+[\d:]+)?',
                            f'@updated {current_time}',
                            updated_content
                        )

                    # 写入更新后的内容
                    with open(filename, "w", encoding='utf-8') as f:
                        f.write(updated_content)
                        print(f'Successfully updated properties in {filename}')
                else:
                    print(f'Warning: Could not find property markers in {filename}')
            else:
                print(f'No property changes detected in {filename}, skipping update')
        else:
            # 如果是新文件，直接生成
            with open(filename, "w", encoding='utf-8') as f:
                f.write(rendered)
                print(f'Successfully generated new file: {filename}')

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix
