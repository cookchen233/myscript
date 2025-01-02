from .base import ApiDocBaseGenerator

class ApiDocUpdateGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/update.jinja2"

    def get_doc_type(self):
        return "更新"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为更新API参数"""
        # 更新接口不需要的字段
        if field_name in self.non_param_fields:
            return False
            
        # 系统管理的时间字段不需要作为参数
        system_time_fields = {
            'create_time', 'update_time', 'deleted_time',
            'created_at', 'updated_at', 'deleted_at'
        }
        if field_name in system_time_fields:
            return False

        # id字段是必需的参数
        if field_name == 'id':
            return True

        # 其他字段都可以作为可选的更新参数
        return True
