# vue_list_generator.py

import os
import re
from datetime import datetime
from .base_generator import BaseGenerator, camel_to_snake, snake_to_camel
from .vue_edit_generator import VueEditGenerator

class VueListGenerator(VueEditGenerator):
    
    def get_template_name(self):
        return "vue_list.jinja2"
    
    def generate(self):
        rendered = self.render()
        
        # 转换路径格式
        module_path = self.module_name.lower()
        
        # 去掉表名中的模块前缀(如bb_)并转换为中划线格式
        page_name = camel_to_snake(self.file_name)
        if module_path:
            # 如果存在模块名，移除表名中的模块前缀
            prefix = f"{module_path}_"
            if page_name.startswith(prefix):
                page_name = page_name[len(prefix):]
        
        # 将下划线转换为中划线
        page_path = page_name.replace('_', '-')
        
        # 组合最终路径
        file_dir = os.path.join(self.rendered_file_dir, module_path, page_path)
        filename = os.path.join(file_dir, "list.vue")
        
        # Skip if file already exists
        if os.path.exists(filename):
            print(f'File already exists, skipping: {filename}')
            return
            
        os.makedirs(file_dir, exist_ok=True)
        
        with open(filename, "w", encoding='utf-8') as f:
            f.write(rendered)
            print(f'Successfully generated: {filename}')
