from .base import ApiDocBaseGenerator

class ApiDocDetailGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/detail.jinja2"

    def get_doc_type(self):
        return "详情"
