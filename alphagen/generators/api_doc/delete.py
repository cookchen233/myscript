from .base import ApiDocBaseGenerator

class ApiDocDeleteGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/delete.jinja2"

    def get_doc_type(self):
        return "删除"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为删除API参数"""
        # 删除接口通常只需要id参数
        if field_name in self.non_param_fields:
            return False
        return field_name == 'id' or field_name.endswith('_id')

    def generate(self):
        import re
        comment = self.get_table_comment(False)

        # 使用正则表达式查找中括号内的内容
        match = re.search(r'\[(.*?)\]', comment)

        if match:
            content = match.group(1)
            if "d" in content:
                super().generate()

