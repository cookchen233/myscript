#!/usr/bin/env python3
import json
import sys
import re
from datetime import datetime
from typing import Dict, Any, Optional, List

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    GRAY = '\033[90m'

class LogParser:
    def __init__(self):
        self.current_request = {}
        
    def parse_request_line(self, line: str) -> Optional[Dict]:
        # 匹配请求行格式: [ 2024-11-01T13:50:33+08:00 ] 10.211.55.2 POST s9ai.jk.com/mobile/index/tallySet
        match = re.match(r'\[ (.*?) \] (.*?) (GET|POST|PUT|DELETE) (.*?)$', line)
        if match:
            return {
                'timestamp': match.group(1),
                'ip': match.group(2),
                'method': match.group(3),
                'path': match.group(4)
            }
        return None

    def parse_header_section(self, lines: List[str]) -> Dict:
        headers = {}
        for line in lines:
            line = line.strip()
            if "=>" in line:
                key, value = line.split('=>', 1)
                key = key.strip().strip("'")
                value = value.strip().strip("',")
                headers[key] = value
        return headers

    def parse_param_section(self, lines: List[str]) -> Dict:
        params = {}
        for line in lines:
            line = line.strip()
            if "=>" in line:
                key, value = line.split('=>', 1)
                key = key.strip().strip("'")
                value = value.strip().strip("',")
                params[key] = value
        return params

    def parse_json_log(self, line: str) -> Optional[Dict]:
        try:
            data = json.loads(line)
            if 'msg' in data:
                try:
                    msg_data = json.loads(data['msg'])
                    return {
                        'type': data.get('type', 'info'),
                        'timestamp': data.get('time'),
                        'trace_id': data.get('traceId'),
                        'content': msg_data
                    }
                except:
                    return data
            return data
        except:
            return None

    def print_request_info(self, request_data: Dict):
        print(f"\n{Colors.BOLD}{Colors.BLUE}Request Information:{Colors.ENDC}")
        print(f"{Colors.GREEN}Timestamp:{Colors.ENDC} {request_data.get('timestamp', 'N/A')}")
        print(f"{Colors.GREEN}Method:{Colors.ENDC} {request_data.get('method', 'N/A')}")
        print(f"{Colors.GREEN}Path:{Colors.ENDC} {request_data.get('path', 'N/A')}")
        print(f"{Colors.GREEN}IP:{Colors.ENDC} {request_data.get('ip', 'N/A')}")
        
        if request_data.get('headers'):
            print(f"\n{Colors.YELLOW}Headers:{Colors.ENDC}")
            for key, value in request_data['headers'].items():
                print(f"  {Colors.GRAY}{key}:{Colors.ENDC} {value}")
            
        if request_data.get('params'):
            print(f"\n{Colors.YELLOW}Parameters:{Colors.ENDC}")
            for key, value in request_data['params'].items():
                print(f"  {Colors.GRAY}{key}:{Colors.ENDC} {value}")

    def print_log_entry(self, log_data: Dict):
        if 'type' in log_data and log_data['type'] == 'error':
            print(f"\n{Colors.RED}Error Log:{Colors.ENDC}")
            print(f"{Colors.YELLOW}Trace ID:{Colors.ENDC} {log_data.get('trace_id', 'N/A')}")
            print(f"{Colors.YELLOW}Timestamp:{Colors.ENDC} {log_data.get('timestamp', 'N/A')}")
            if 'content' in log_data:
                print(f"{Colors.YELLOW}Content:{Colors.ENDC}")
                print(json.dumps(log_data['content'], indent=2, ensure_ascii=False))
        else:
            print(f"\n{Colors.GREEN}Info Log:{Colors.ENDC}")
            print(json.dumps(log_data, indent=2, ensure_ascii=False))

    def process_line(self, line: str):
        line = line.strip()
        if not line or line.startswith('---'):
            return

        # 尝试解析请求行
        request_info = self.parse_request_line(line)
        if request_info:
            if self.current_request:
                self.print_request_info(self.current_request)
            self.current_request = request_info
            return

        # 处理 HEADER 部分
        if '[ HEADER ]' in line:
            self.current_section = 'header'
            self.current_request['headers'] = {}
            return

        # 处理 PARAM 部分
        if '[ PARAM ]' in line:
            self.current_section = 'param'
            self.current_request['params'] = {}
            return

        # 处理 JSON 日志
        if line.startswith('{'):
            log_data = self.parse_json_log(line)
            if log_data:
                self.print_log_entry(log_data)
            return

        # 处理 header 和 param 的内容
        if hasattr(self, 'current_section'):
            if self.current_section == 'header' and '=>' in line:
                key, value = line.strip().split('=>', 1)
                key = key.strip().strip("'")
                value = value.strip().strip("',")
                self.current_request.setdefault('headers', {})[key] = value
            elif self.current_section == 'param' and '=>' in line:
                key, value = line.strip().split('=>', 1)
                key = key.strip().strip("'")
                value = value.strip().strip("',")
                self.current_request.setdefault('params', {})[key] = value

def main():
    parser = LogParser()
    try:
        for line in sys.stdin:
            parser.process_line(line)
    except KeyboardInterrupt:
        print("\nExiting...")
        sys.exit(0)

if __name__ == "__main__":
    main()