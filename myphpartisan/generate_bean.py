# Gnerate PHP beans

from pprint import pprint
import os,jinja2
    
class GenerateBean(object):
    
    def __init__(self, rendered_file_dir=""):
        self.rendered_file_dir=rendered_file_dir
        if not os.path.exists(self.rendered_file_dir):
            os.makedirs(self.rendered_file_dir)
        self.jinja2_env=jinja2.Environment(loader=jinja2.PackageLoader('resource', 'templates'))
            
    def _snake_to_camel(self, snake_str):
        components = snake_str.split('_')
        # Capitalize the first letter of each word except the first one
        return components[0] + ''.join(x.title() for x in components[1:])
    
    def render_bean_class(self):
        return self.bean_name
            
    def generate_bean(self):
        rendered=self.render_bean_class()
        filename=os.path.join(self.rendered_file_dir, self.bean_name+".php")
        with open(filename, "w") as f:
            f.write(rendered)
        
        print(rendered)
