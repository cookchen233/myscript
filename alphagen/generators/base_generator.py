from datetime import datetime
import jinja2
import os
import pymysql
from utils import *


class BaseGenerator(object):
    def __init__(self, file_name, rendered_file_dir=""):
        self.file_name = file_name
        self.pymysql_connection = None
        self.rendered_file_dir = rendered_file_dir
        if self.rendered_file_dir == "":
            self.rendered_file_dir = os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                                  "resource/rendered_files")

        # 确保目录存在
        os.makedirs(os.path.dirname(self.rendered_file_dir), exist_ok=True)
        self.jinja2_env = jinja2.Environment(loader=jinja2.PackageLoader('resource', 'templates'))

        self.jinja2_env.filters['camel_to_snake'] = camel_to_snake
        self.jinja2_env.filters['snake_to_camel'] = snake_to_camel

        self.force = False  # 添加force属性

    def set_force(self, force):
        self.force = force

    def __del__(self):
        if hasattr(self, 'pymysql_connection') and self.pymysql_connection is not None:
            self.pymysql_connection.close()

    def set_mysql_connection(self, host='localhost', port=3306, user='root', password='', db='baibuyinshe',
                             charset='utf8'):
        self.pymysql_connection = pymysql.connect(host=host, port=port, user=user, password=password, db=db,
                                                  charset=charset)

    def _get_table_schema(self, table_name):
        with self.pymysql_connection.cursor() as cursor:
            query = f"SHOW FULL COLUMNS FROM {table_name}"
            cursor.execute(query)
            return self._get_rows_from_cursor(cursor)

    def _get_table_status(self, table_name, key):
        try:
            with self.pymysql_connection.cursor() as cursor:
                cursor.execute("SELECT DATABASE()")
                current_db = cursor.fetchone()[0]

                query = f"SHOW TABLE STATUS LIKE '{table_name}'"
                cursor.execute(query)
                row = cursor.fetchone()

                if row is None:
                    raise Exception(f"数据库[{current_db}]找不到表[{table_name}]")

                field_names = [desc[0] for desc in cursor.description]
                row_dict = dict(zip(field_names, row))
                return row_dict[key]

        except Exception as e:
            print(f"错误信息: {str(e)}")
            print(f"数据库连接信息: {self.pymysql_connection.get_host_info()}")
            raise

    def _get_rows_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchall()
        rows = []
        for row in result:
            rows.append(dict(zip(column_names, row)))
        return rows

    def get_template_name(self):
        raise NotImplementedError("Subclasses must implement get_template_name()")

    def get_template_variables(self):
        raise NotImplementedError("Subclasses must implement get_template_variables()")

    def render(self):
        template = self.jinja2_env.get_template(self.get_template_name())
        return template.render(self.get_template_variables())

    def _should_update_file(self, filename: str) -> bool:
        """检查是否应该更新现有文件"""
        if not os.path.exists(filename):
            return True

        # 读取现有文件的生成时间
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
            if '@generated' not in content:
                # 如果文件中没有生成标记，认为是手动创建的文件
                return False
        return True

    def _add_file_header(self, content: str) -> str:
        """添加文件头注释"""
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header = f"""<?php
/**
 * This file is auto-generated.
 * 
 * @generated {now}
 * @generator AlphaGenerator
 */

"""
        return header + content.lstrip('<?php')

    def generate(self):
        rendered = self._add_file_header(self.render())
        filename = os.path.join(self.rendered_file_dir, self.file_name + ".php")

        # 确保目录存在
        os.makedirs(os.path.dirname(filename), exist_ok=True)

        if not self._should_update_file(filename):
            print(f'Skipping file: {filename} (manually created or modified)')
            return

        with open(filename, "w", encoding='utf-8') as f:
            f.write(rendered)
            print(f'Successfully generated: {filename}')