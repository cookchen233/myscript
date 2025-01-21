from .base import ApiDocBaseGenerator

class ApiDocUpdateGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/update.jinja2"

    def get_doc_type(self):
        return "更新"

    def _should_be_parameter(self, field_name, field_type, comment):
            """判断字段是否应该作为创建API参数"""
            # 更新接口不需要的字段
            self.non_param_fields = {
                'deleted_time', 'create_time', 'update_time',
                'site_id',
                'member_id',
                'admin_id',
            }
            if field_name in self.non_param_fields:
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
            if "u" in content:
                super().generate()
