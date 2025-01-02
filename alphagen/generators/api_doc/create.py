from .base import ApiDocBaseGenerator

class ApiDocCreateGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/create.jinja2"

    def get_doc_type(self):
        return "创建"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为创建API参数"""
        # 创建接口不需要的字段
        if field_name in self.non_param_fields:
            return False
            
        # 自动生成或系统管理的字段不需要作为参数
        auto_generated_fields = {
            'id', 'create_time', 'update_time', 'deleted_time',
            'created_at', 'updated_at', 'deleted_at'
        }
        if field_name in auto_generated_fields:
            return False

        # 大多数其他字段都应该作为创建参数
        return True
