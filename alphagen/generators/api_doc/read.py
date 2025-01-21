from .base import ApiDocBaseGenerator

class ApiDocReadGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/read.jinja2"

    def get_doc_type(self):
        return "详情"

