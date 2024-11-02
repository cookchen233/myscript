#!/usr/bin/python3
# Gnerate PHP beans from mysql tables

from peewee import *
from pprint import pprint
from .. import GenerateBean
import pymysql,os,jinja2
    
class GenerateTableBean(GenerateBean):
    
    def __init__(self, rendered_file_dir=""):
        self.connection = pymysql.connect(host='localhost', port=3306, user='root', password='', db='baibuyinshe', charset='utf8')
        self.rendered_file_dir=rendered_file_dir
        if not os.path.exists(self.rendered_file_dir):
            os.makedirs(self.rendered_file_dir)
        self.jinja2_env=jinja2.Environment(loader=jinja2.PackageLoader('resource', 'templates'))
        
    def __del__(self):
        if hasattr(self, 'connection') and self.connection:
            self.connection.close()
            
    def get_table_schema(self, table_name):
        with self.connection.cursor() as cursor:
                query = f"SHOW FULL COLUMNS FROM {table_name}"
                cursor.execute(query)
                return self._get_rows_from_cursor(cursor)
            
    def get_table_info(self, table_name):
        with self.connection.cursor() as cursor:
                query = f"SHOW TABLE STATUS LIKE '{table_name}'"
                cursor.execute(query)
                return self._get_row_from_cursor(cursor)
            
    def _get_rows_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchall()
        rows=[]
        for row in result:
            rows.append(dict(zip(column_names, row)))
        return rows
        
    def _get_row_from_cursor(self, cursor):
        column_names = [column[0] for column in cursor.description]
        result = cursor.fetchone()
        if result:
            return dict(zip(column_names, result))
        else:
            return None

            
    def _snake_to_camel(self, snake_str):
        components = snake_str.split('_')
        # Capitalize the first letter of each word except the first one
        return components[0] + ''.join(x.title() for x in components[1:])
    
    def render_bean_class(self):
        template_name = "bean_template.php"
        template = self.jinja2_env.get_template(template_name)
        rendered = template.render(
            table_name=self.table_name,
            table_comment=self.table_info["Comment"],
            bean_name=self.bean_name,
            properties=self.get_properties_from_schema(self.table_schema),
        )
        return rendered
    
    def get_properties_from_schema(self, table_schema):
        properties=[]
        for field in table_schema:
            if 'int' in field["Type"] or 'float' in field["Type"] or 'decimal' in field["Type"]:
                property_type="int"
            else:
                property_type="string"
            property=dict(
                name=self._snake_to_camel(field["Field"]),
                property_type=property_type,
                field_name=field["Field"],
                field_comment=field["Comment"],
                set_method_name=self._snake_to_camel("set_"+field["Field"]),
                get_method_name=self._snake_to_camel("get_"+field["Field"]),
            )
            properties.append(property)
        return properties
    
    def set_table(self, table_name):
        self.table_name = table_name
        self.table_info=generate_php_bean.get_table_info(table_name)
        self.table_schema=generate_php_bean.get_table_schema(table_name)
        self.bean_name=self._snake_to_camel(table_name.replace("tp", "")+"_bean")
        self.properties=self.get_properties_from_schema(self.table_schema)
            
    def generate_table_bean(self, table_name):
        self.set_table(table_name)
        rendered=self.render_bean_class()
        filename=os.path.join(self.rendered_file_dir, self.bean_name+".php")
        print(filename)
        with open(filename, "w") as f:
            f.write(rendered)
        
        print(rendered)

rendered_file_dir=os.path.join(os.path.dirname(os.path.realpath(__file__)), "resource/redered_files")
generate_php_bean = GeneratePhpBean(rendered_file_dir)
generate_php_bean.generate("tp_device_operations_management")
