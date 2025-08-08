#!/usr/bin/python3
# main.py
import os
import sys
import argparse

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from alphagen.generator import Generator

def main():
    parser = argparse.ArgumentParser(description='代码生成工具')
    # 以下是用于之前的PHP项目
    parser.add_argument('paths', nargs='+', help='格式: module_name/table_name，例如: admin/user admin/role ...')
    parser.add_argument('--dto', action='store_true', help='仅生成DTO文件')
    parser.add_argument('--model', action='store_true', help='仅生成Model文件')
    parser.add_argument('--enum', action='store_true', help='仅生成Enum文件')
    parser.add_argument('--comment', help='类注释 (仅用于DTO)')
    parser.add_argument('--properties', help='属性定义 (仅用于DTO)')
    parser.add_argument('--force', '-f', action='store_true', help='强制覆盖已存在的文件')
    parser.add_argument('--site_id', help='指定站点 ID', required=False)  # 新增的参数

    # Go 项目生成
    parser.add_argument('--go', action='store_true', help='生成 Go(ent) 全流程文件')
    parser.add_argument('--go_project', help='Go 项目根目录，默认当前目录', default=os.getcwd())

    args = parser.parse_args()
    generator = Generator()

    # 设置force选项
    generator.set_force(args.force)

    if args.site_id:
        generator.set_site_id(args.site_id)

    if args.dto:
        if not args.comment or not args.properties:
            parser.error("生成DTO需要提供 --comment 和 --properties 参数")
        for path in args.paths:
            generator.generate_dto(path, args.comment, args.properties)
    elif args.model:
        for path in args.paths:
            generator.generate_model(path)
    elif args.enum:
        for path in args.paths:
            generator.generate_enum(path)
    elif args.go:
        # 延迟导入避免不必要的依赖
        from alphagen.generators.go_flow_generator import GoFlowGenerator
        go_gen = GoFlowGenerator(project_root=args.go_project, force=args.force)
        for path in args.paths:
            go_gen.generate(path)
    else:
        for path in args.paths:
            generator.generate_all(path)

if __name__ == "__main__":
    main()
