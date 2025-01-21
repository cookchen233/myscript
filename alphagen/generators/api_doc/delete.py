from .base import ApiDocBaseGenerator

class ApiDocDeleteGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/delete.jinja2"

    def get_doc_type(self):
        return "删除"

    def generate(self):
        import re
        comment = self.get_table_comment(False)

        # 使用正则表达式查找中括号内的内容
        match = re.search(r'\[(.*?)\]', comment)

        if match:
            content = match.group(1)
            if "d" in content:
                super().generate()

