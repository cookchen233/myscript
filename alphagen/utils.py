from datetime import datetime


def snake_to_camel(snake_str, capitalize_first=False):
    """
    将蛇形命名转换为驼峰命名
    :param snake_str: 蛇形命名的字符串
    :param capitalize_first: 是否大写首字母
    :return: 驼峰命名的字符串
    """
    components = snake_str.split('_')
    if capitalize_first:
        return ''.join(x.title() for x in components)
    return components[0] + ''.join(x.title() for x in components[1:])


def camel_to_snake(camel_str):
    """
    将驼峰命名转换为蛇形命名
    :param camel_str: 驼峰命名的字符串
    :return: 蛇形命名的字符串
    """
    result = ''
    for i, char in enumerate(camel_str):
        if i > 0 and char.isupper():
            result += '_'
        result += char.lower()
    return result


def format_date(value, format='%Y-%m-%d %H:%M:%S'):
    """自定义的日期格式化过滤器"""
    return datetime.now().strftime(format)
