from .base import ApiDocBaseGenerator

class ApiDocCreateGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/create.jinja2"

    def get_doc_type(self):
        return "创建"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为创建API参数"""
        # 创建接口不需要的字段
        self.non_param_fields = {
            'id',
            'create_time', 
            'update_time',
            'deleted_time', 
            'site_id',
            'member_id',
            'admin_id',
            'audit_time', 
            'audit_status', 
            'audit_admin_id', 
            'views',
            'sales',
        }
        if field_name in self.non_param_fields:
            return False
        
        if field_name.endswith('_status'):
            return False

        # 大多数其他字段都应该作为创建参数
        return True

    def generate(self):
        import re
        comment = self.get_table_comment(False)

        # 使用正则表达式查找中括号内的内容
        match = re.search(r'\[(.*?)\]', comment)

        if match:
            content = match.group(1)
            if "c" in content:
                super().generate()
