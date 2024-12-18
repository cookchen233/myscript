from .base import ApiDocBaseGenerator

class ApiDocListGenerator(ApiDocBaseGenerator):
    def get_template_name(self):
        return "api_doc/list.jinja2"

    def get_doc_type(self):
        return "列表"

    def _should_be_parameter(self, field_name, field_type, comment):
        """判断字段是否应该作为列表API参数"""
        # 列表接口的常见筛选参数
        common_list_params = {'status', 'type', 'category', 'level', 'is_enabled', 'is_deleted'}

        # 如果字段名在非参数列表中，直接返回False
        if field_name in self.non_param_fields:
            return False

        # 列表常用的筛选字段
        if field_name in common_list_params:
            return True

        # 检查字段名后缀，列表接口常用的筛选条件后缀
        list_param_suffixes = {'_status', '_type', '_id', '_code', '_no'}
        for suffix in list_param_suffixes:
            if field_name.endswith(suffix):
                return True

        # 检查字段类型，大文本类型通常不是参数
        if 'text' in field_type.lower() or 'json' in field_type.lower():
            return False

        # 时间字段作为范围查询参数
        if '_time' in field_name or '_at' in field_name or '_date' in field_name:
            return True

        return False
