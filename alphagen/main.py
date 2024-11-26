#!/usr/bin/python3
# main.py
import argparse
from generator import Generator

def main():
    parser = argparse.ArgumentParser(description='代码生成工具')
    parser.add_argument('paths', nargs='+', help='格式: module_name/table_name，例如: admin/user admin/role ...')
    parser.add_argument('--dto', action='store_true', help='仅生成DTO文件')
    parser.add_argument('--comment', help='类注释 (仅用于DTO)')
    parser.add_argument('--properties', help='属性定义 (仅用于DTO)')
    parser.add_argument('--force', '-f', action='store_true', help='强制覆盖已存在的文件')

    args = parser.parse_args()
    generator = Generator()
    
    # 设置force选项
    generator.set_force(args.force)

    if args.dto:
        if not args.comment or not args.properties:
            parser.error("生成DTO需要提供 --comment 和 --properties 参数")
        for path in args.paths:
            generator.generate_dto(path, args.comment, args.properties)
    else:
        for path in args.paths:
            generator.generate_all(path)

if __name__ == "__main__":
    main()