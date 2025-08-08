#!/usr/bin/python3
"""GoFlowGenerator - generate Go ent schema, service, handler, route, curl files
This generator is lightweight: it relies on simple Jinja2 templates located in
alphagen/templates/go/*.jinja2.  It does NOT inspect the database, it just
creates skeleton files that developers can tweak later.
"""
import os
import jinja2
from typing import Dict

from alphagen.utils import snake_to_camel, camel_to_snake

TEMPLATE_DIR = os.path.join(os.path.dirname(os.path.realpath(__file__)), '../templates/go')

class GoFlowGenerator:
    def __init__(self, project_root: str, force: bool = False, exemplar: str = 'deployment_task_log'):
        """project_root is the Go project root directory (e.g. path containing ent/, services/).
        """
        self.project_root = project_root
        self.force = force
        self.exemplar = exemplar  # base entity to copy from
        self.env = jinja2.Environment(loader=jinja2.FileSystemLoader(TEMPLATE_DIR))

    def _render(self, template_name: str, vars_: Dict[str, str]) -> str:
        tpl = self.env.get_template(template_name)
        return tpl.render(**vars_)

    def _write(self, target_path: str, content: str):
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        if os.path.exists(target_path) and not self.force:
            print(f"Skip existing file: {target_path}")
            return
        with open(target_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Generated: {target_path}")

    def _copy_and_replace(self, src_rel: str, dst_path: str, ctx: Dict[str, str]):
        src_path = os.path.join(self.project_root, src_rel)
        if not os.path.exists(src_path):
            print(f"Exemplar file not found: {src_path}; skipping copy")
            return
        with open(src_path, 'r', encoding='utf-8') as f:
            content = f.read()
        exemplar_entity_camel = 'DeploymentTaskLog'
        exemplar_entity_snake = 'deployment_task_log'
        exemplar_pkg = 'deploymenttasklog'
        exemplar_service = 'DeploymentTaskLogService'
        exemplar_filter = 'FilterDeploymentTaskLog'

        # replacements
        content = content.replace(exemplar_service, f"{ctx['Entity']}Service")
        content = content.replace(exemplar_entity_camel, ctx['Entity'])
        content = content.replace(exemplar_filter, f"Filter{ctx['Entity']}")
        content = content.replace(exemplar_pkg, ctx['entity_pkg'])
        content = content.replace(exemplar_entity_snake, ctx['entity_snake'])

        self._write(dst_path, content)

    def generate(self, path: str):
        """path format: module_name/table_name OR table_name"""
        parts = path.split('/')
        if len(parts) == 2:
            module_name, table_name = parts
        else:
            module_name = ''
            table_name = parts[0]

        entity_camel = snake_to_camel(table_name, True)
        entity_lc_camel = snake_to_camel(table_name, False)
        entity_snake = camel_to_snake(entity_camel)
        entity_pkg = entity_snake.replace('_', '')
        ctx = {
            'Entity': entity_camel,
            'entity_snake': entity_snake,
            'entity_pkg': entity_pkg,
            'entity_lc_camel': entity_lc_camel,
        }

        # 1. schema
        schema_dir = os.path.join(self.project_root, 'ent', 'schemas')
        self._write(os.path.join(schema_dir, f"{entity_snake}.go"), self._render('schema.go.jinja2', ctx))

        # 2. service (copy exemplar and replace)
        service_dir = os.path.join(self.project_root, 'services')
        self._copy_and_replace(f"services/{self.exemplar}.go", os.path.join(service_dir, f"{entity_snake}.go"), ctx)

        # 3. handler
        handler_dir = os.path.join(self.project_root, 'handlers', 'api')
        self._copy_and_replace(f"handlers/api/{self.exemplar}.go", os.path.join(handler_dir, f"{entity_snake}.go"), ctx)

        # 4. route snippet (placed in routes/auto_{entity}.go)
        routes_dir = os.path.join(self.project_root, 'routes')
        self._write(os.path.join(routes_dir, f"auto_{entity_snake}_routes.go"), self._render('route.go.jinja2', ctx))

        # 5. curl script
        self._write(os.path.join(handler_dir, f"{entity_snake}_api.sh"), self._render('curl.sh.jinja2', ctx))

        print("Go flow generation completed. Remember to run 'ent generate' to build ent code and wire up the new routes in main.go if needed.")
