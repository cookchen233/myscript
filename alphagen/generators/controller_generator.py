import os
import re
from datetime import datetime

from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class ControllerGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""

    def get_template_name(self):
        return "controller.jinja2"

    def get_template_variables(self):
        base_name = self.file_name.replace("Controller", "")
        table_name = self.table_prefix + camel_to_snake(base_name)

        return dict(
            table_name=table_name,
            table_prefix=self.table_prefix,
            module_name=self.module_name,
            class_name=self.file_name,
            model_variable_name="$" + snake_to_camel(camel_to_snake(self.file_name)),
            table_comment=self._get_table_status(table_name, "Comment"),
            properties=self._get_model_properties(table_name),
            datetime=datetime  # 添加 datetime 对象
        )

    def _get_model_properties(self, table_name):
        table_schema = self._get_table_schema(table_name)
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

    def generate(self):
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        rendered = self.render()
        filename = os.path.join(self.rendered_file_dir, self.file_name + ".php")

        # 确保目录存在
        os.makedirs(os.path.dirname(filename), exist_ok=True)
    
        if not self.force and os.path.exists(filename):
            print(f'File already exists, skipping: {filename}')
            return
        else:
            # 如果是新文件，直接生成
            with open(filename, "w", encoding='utf-8') as f:
                f.write(rendered)
                print(f'Successfully generated new file: {filename}')

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix