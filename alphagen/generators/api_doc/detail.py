from .base import ApiDocBaseGenerator

class ApiDocDetailGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/detail.jinja2"

    def get_doc_type(self):
        return "详情"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为详情API参数"""
        # 详情接口通常只需要id参数
        if field_name in self.non_param_fields:
            return False
        return field_name == 'id' or field_name.endswith('_id')
