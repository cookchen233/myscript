from .base import ApiDocBaseGenerator

class ApiDocListGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/list.jinja2"

    def get_doc_type(self):
        return "列表"
