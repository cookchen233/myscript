#!/usr/bin/python3
import os
from typing import List
from config import DEFAULT_CONFIGS
from generators.model_generator import ModelGenerator
from generators.bean_generator import BeanGenerator
from generators.dao_generator import DaoGenerator, BasicDaoGenerator
from generators.dto_generator import DtoGenerator
from utils import snake_to_camel


class Generator:
    def __init__(self):
        self.base_paths = DEFAULT_CONFIGS['paths']
        self.mysql_config = DEFAULT_CONFIGS['mysql']
        self.table_prefix = DEFAULT_CONFIGS["table_prefix"]

    def parse_path(self, path: str) -> tuple:
        """解析路径，返回(模块名, 表名)"""
        if not path or '/' not in path:
            raise ValueError("无效的路径格式，应该是: module_name/table_name")

        parts = path.split('/')
        if len(parts) != 2:
            raise ValueError("路径格式必须为: module_name/table_name")

        module_name, table_name = parts
        if not module_name or not table_name:
            raise ValueError("模块名和表名不能为空")

        return module_name, table_name

    def generate_all(self, path: str) -> None:
        """生成所有相关文件"""
        try:
            module_name, table_name = self.parse_path(path)
            class_name = snake_to_camel(table_name, True)  # 转换表名为驼峰形式

            # 生成Model
            model_generator = ModelGenerator(
                class_name + "Model",
                os.path.join(self.base_paths['model'], module_name)
            )
            model_generator.set_mysql_connection(**self.mysql_config)
            model_generator.set_module_name(module_name)
            model_generator.set_table_prefix(self.table_prefix)
            model_generator.generate()

            # 生成Bean
            # bean_generator = BeanGenerator(
            #     class_name + "Bean",
            #     os.path.join(self.base_paths['bean'], module_name)
            # )
            # bean_generator.set_mysql_connection(**self.mysql_config)
            # bean_generator.set_module_name(module_name)
            # bean_generator.set_table_prefix(self.table_prefix)
            # bean_generator.generate()

            # 生成Dao
            # dao_generator = DaoGenerator(
            #     class_name + "Dao",
            #     os.path.join(self.base_paths['dao'], module_name)
            # )
            # dao_generator.set_mysql_connection(**self.mysql_config)
            # dao_generator.set_module_name(module_name)
            # dao_generator.set_table_prefix(self.table_prefix)
            # dao_generator.generate()

            # 生成BasicDao
            # basic_dao_generator = BasicDaoGenerator(
            #     class_name + "BasicDao",
            #     os.path.join(self.base_paths['basic_dao'], module_name)
            # )
            # basic_dao_generator.set_mysql_connection(**self.mysql_config)
            # basic_dao_generator.set_module_name(module_name)
            # basic_dao_generator.set_table_prefix(self.table_prefix)
            # basic_dao_generator.generate()

        except Exception as e:
            print(f"Error generating files: {str(e)}")
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
