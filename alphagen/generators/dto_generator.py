import re
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class DtoGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.class_comment = ""
        self.dto_properties = []

    def get_template_name(self):
        return "dto2.jinja2"

    def get_template_variables(self):
        return dict(
            class_name=self.file_name,
            class_comment=self.class_comment,
            module_name=self.module_name,
            properties=self.dto_properties,
            class_variable_name="$" + snake_to_camel(camel_to_snake(self.file_name))
        )

    def set_dto_properties(self, text):
        dto_properties = []
        pattern = r"'.*?[\.\s]+(\w+)'\s*,?\s*//\s*(\w+)\s*(\w+)?"
        matches = re.findall(pattern, text)

        for match in matches:
            field_name = match[0]
            dto_properties.append({
                "name": snake_to_camel(field_name),
                "field_name": field_name,
                "property_type": match[1] if match[1] else "string",
                "field_comment": match[2] if match[2] else "",
                "set_method_name": snake_to_camel("set_" + field_name),
                "get_method_name": snake_to_camel("get_" + field_name),
            })
        self.dto_properties = dto_properties

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_class_comment(self, comment):
        self.class_comment = comment