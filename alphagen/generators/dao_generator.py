from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel

class DaoGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = ""

    def get_template_name(self):
        return "table_dao.jinja2"

    def get_template_variables(self):
        base_name = self.file_name.replace("Dao", "")
        table_name = self.table_prefix + camel_to_snake(base_name)

        return dict(
            table_name=table_name,
            class_name=self.file_name,
            module_name=self.module_name,
            basic_class_name=self.file_name.replace('Dao', 'BasicDao'),
            bean_name=self.file_name.replace('Dao', 'Bean'),
            bean_variable_name="$" + snake_to_camel(self.file_name),
            table_comment=self._get_table_status(table_name, "Comment")
        )

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix


class BasicDaoGenerator(BaseGenerator):
    def __init__(self, file_name, rendered_file_dir=""):
        super().__init__(file_name, rendered_file_dir)
        self.module_name = ""
        self.table_prefix = "tp_"

    def get_template_name(self):
        return "table_basic_dao.jinja2"

    def get_template_variables(self):
        base_name = self.file_name.replace("BasicDao", "")
        table_name = self.table_prefix + camel_to_snake(base_name)
        model_name = base_name
        bean_name = base_name + 'Bean'

        return dict(
            table_name=table_name,
            class_name=self.file_name,
            module_name=self.module_name,
            model_name=model_name,
            bean_name=bean_name,
            bean_variable_name="$" + snake_to_camel(camel_to_snake(bean_name)),
            table_comment=self._get_table_status(table_name, "Comment")
        )

    def set_module_name(self, module_name):
        self.module_name = module_name

    def set_table_prefix(self, prefix):
        self.table_prefix = prefix