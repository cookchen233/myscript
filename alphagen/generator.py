#!/usr/bin/python3
# generator.py
import os
from typing import List

from alphagen.generators.api_doc import ApiDocListGenerator, ApiDocDetailGenerator
from config import DEFAULT_CONFIGS
from generators.model_generator import ModelGenerator
from generators.controller_generator import ControllerGenerator
from generators.bean_generator import BeanGenerator
from generators.dao_generator import DaoGenerator, BasicDaoGenerator
from generators.dto_generator import DtoGenerator
from generators.vue_edit_generator import VueEditGenerator
from generators.vue_list_generator import VueListGenerator
from generators.enum_generator import EnumGenerator
from utils import snake_to_camel


class Generator:
    def __init__(self):
        self.base_paths = DEFAULT_CONFIGS['paths']
        self.mysql_config = DEFAULT_CONFIGS['mysql']
        self.table_prefix = DEFAULT_CONFIGS["table_prefix"]

        self.force = False

    def set_force(self, force):
        self.force = force

    def parse_path(self, path: str) -> tuple:
        """
        解析路径，返回(模块名, 表名)
        如果包含斜杠，则第一部分为模块名；
        如果没有斜杠，则模块名为空，整个路径为表名
        """
        if not path:
            raise ValueError("路径不能为空")

        parts = path.split('/')

        if len(parts) > 2:
            raise ValueError("路径格式错误，应该是: module_name/table_name 或 table_name")

        if len(parts) == 2:
            # 包含模块名: admin/user
            module_name, table_name = parts
            if not module_name or not table_name:
                raise ValueError("模块名和表名不能为空")
            return module_name, table_name
        else:
            # 直接是表名: user
            return "", parts[0]

        return module_name, table_name

    def generate_all(self, path: str) -> None:
        """生成所有相关文件"""
        try:
            module_name, table_name = self.parse_path(path)
            class_name = snake_to_camel(table_name, True)  # 转换表名为驼峰形式

            # 生成枚举（添加在其他生成器之前）
            self.generate_enum(path)

            # 生成Model
            model_generator = ModelGenerator(
                class_name + "Model",
                os.path.join(self.base_paths['model'], module_name)
            )
            model_generator.set_mysql_connection(**self.mysql_config)
            model_generator.set_module_name(module_name)
            model_generator.set_table_prefix(self.table_prefix)
            model_generator.set_force(self.force)
            model_generator.generate()

            # 生成控制器
            controller_generator = ControllerGenerator(
                class_name,
                os.path.join(self.base_paths['controller'], module_name)
            )
            controller_generator.set_mysql_connection(**self.mysql_config)
            controller_generator.set_module_name(module_name)
            controller_generator.set_table_prefix(self.table_prefix)
            controller_generator.set_force(self.force)
            controller_generator.generate()

            # 生成接口文档
            api_doc_list_generator = ApiDocListGenerator(
                class_name,
                os.path.join(self.base_paths['api_doc'], module_name)
            )
            api_doc_list_generator.set_mysql_connection(**self.mysql_config)
            api_doc_list_generator.set_module_name(module_name)
            api_doc_list_generator.set_table_prefix(self.table_prefix)
            api_doc_list_generator.set_force(self.force)
            api_doc_list_generator.generate()

            api_doc_detail_generator = ApiDocDetailGenerator(
                class_name,
                os.path.join(self.base_paths['api_doc'], module_name)
            )
            api_doc_detail_generator.set_mysql_connection(**self.mysql_config)
            api_doc_detail_generator.set_module_name(module_name)
            api_doc_detail_generator.set_table_prefix(self.table_prefix)
            api_doc_detail_generator.set_force(self.force)
            api_doc_detail_generator.generate()

            # 生成Bean
            # bean_generator = BeanGenerator(
            #     class_name + "Bean",
            #     os.path.join(self.base_paths['bean'], module_name)
            # )
            # bean_generator.set_mysql_connection(**self.mysql_config)
            # bean_generator.set_module_name(module_name)
            # bean_generator.set_table_prefix(self.table_prefix)
            # model_generator.set_force(self.force)
            # bean_generator.generate()

            # 生成Dao
            # dao_generator = DaoGenerator(
            #     class_name + "Dao",
            #     os.path.join(self.base_paths['dao'], module_name)
            # )
            # dao_generator.set_mysql_connection(**self.mysql_config)
            # dao_generator.set_module_name(module_name)
            # dao_generator.set_table_prefix(self.table_prefix)
            # dao_generator.set_force(self.force)
            # dao_generator.generate()

            # 生成BasicDao
            # basic_dao_generator = BasicDaoGenerator(
            #     class_name + "BasicDao",
            #     os.path.join(self.base_paths['basic_dao'], module_name)
            # )
            # basic_dao_generator.set_mysql_connection(**self.mysql_config)
            # basic_dao_generator.set_module_name(module_name)
            # basic_dao_generator.set_table_prefix(self.table_prefix)
            # basic_dao_generator.set_force(self.force)
            # basic_dao_generator.generate()

            # 生成edit.vue
            vue_edit_generator = VueEditGenerator(
                class_name,
                self.base_paths['vue_edit']
            )
            vue_edit_generator.set_mysql_connection(**self.mysql_config)
            vue_edit_generator.set_module_name(module_name)
            vue_edit_generator.set_table_prefix(self.table_prefix)
            vue_edit_generator.set_force(self.force)
            vue_edit_generator.generate()

            # 生成list.vue
            vue_list_generator = VueListGenerator(
                class_name,
                self.base_paths['vue_list']
            )
            vue_list_generator.set_mysql_connection(**self.mysql_config)
            vue_list_generator.set_module_name(module_name)
            vue_list_generator.set_table_prefix(self.table_prefix)
            vue_list_generator.set_force(self.force)
            vue_list_generator.generate()


        except Exception as e:
            print(f"Error generating files: {str(e)}")
            raise

    def generate_enum(self, path: str) -> None:
        """根据传入的模块名和表名生成对应表中的枚举类"""
        try:
            module_name, table_name = self.parse_path(path)
            table_name_with_prefix = self.table_prefix + table_name  # 加上表前缀

            # 创建枚举生成器实例来检查表结构
            temp_generator = EnumGenerator("TempEnum")
            temp_generator.set_mysql_connection(**self.mysql_config)
            temp_generator.set_table_name(table_name)  # 设置完整的表名

            # 直接使用完整表名获取枚举字段
            enum_fields = temp_generator._get_enum_fields(table_name_with_prefix)

            # 只有当存在枚举字段时才生成对应的枚举类
            if enum_fields:
                for field in enum_fields:
                    # 为每个枚举字段生成一个独立的枚举类
                    enum_class_name = snake_to_camel(field['field_name'], True) + ""

                    enum_generator = EnumGenerator(
                        enum_class_name,
                        os.path.join(self.base_paths['enum'], module_name)
                    )
                    enum_generator.set_mysql_connection(**self.mysql_config)
                    enum_generator.set_module_name(module_name)
                    enum_generator.set_table_prefix(self.table_prefix)
                    enum_generator.set_table_name(table_name)  # 设置完整的表名
                    enum_generator.set_force(self.force)
                    enum_generator.generate()

                    print(f"Generated enum class for field: {field['field_name']}")
            else:
                print(f"No enum fields found in table: {table_name_with_prefix}")

        except Exception as e:
            print(f"Error generating enum files: {str(e)}")
            raise

    def generate_dto(self, path: str, comment: str, properties: str) -> None:
        """生成DTO文件"""
        module_name, class_name = self.parse_path(path)

        generator = DtoGenerator(
            class_name + "Dto",
            os.path.join(self.base_paths['dto'], module_name)
        )
        generator.set_module_name(module_name)
        generator.set_class_comment(comment)
        generator.set_dto_properties(properties)
        generator.generate()
