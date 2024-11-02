#!/usr/bin/env python3
import os
import time
import hashlib
import smtplib
import subprocess
from email.mime.text import MIMEText
from datetime import datetime, date
from pathlib import Path
from typing import List, Dict
from dotenv import load_dotenv

def get_env_file_hash():
    """获取.env文件的哈希值"""
    # 获取当前脚本所在的目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # 构造.env文件的完整路径
    env_path = Path(script_dir) / '.env'
    
    if not env_path.exists():
        return None
    return hashlib.md5(env_path.read_bytes()).hexdigest()

class ConfigManager:
    def __init__(self):
        self.env_hash = None
        self.configs = None
        self.email_config = None
        self.update_configs()
    
    def update_configs(self):
        """更新配置"""
        load_dotenv()
        
        # 更新仓库配置
        self.configs = self._get_repo_configs()
        
        # 更新邮件配置
        self.email_config = {
            "smtp_server": os.getenv("GIT_SMTP_HOST", "smtp.163.com"),
            "smtp_port": int(os.getenv("GIT_SMTP_PORT", "465")),
            "sender_email": os.getenv("GIT_SMTP_USER"),
            "sender_password": os.getenv("GIT_SMTP_PASS"),
            "receiver_email": os.getenv("GIT_MAIL_TO"),
            "min_interval": 3600,
            "max_daily_emails": 3,
            "enabled": os.getenv("GIT_ENABLE_MAIL", False),
        }
        
        # 验证必要的环境变量
        required_env_vars = ["GIT_SMTP_USER", "GIT_SMTP_PASS", "GIT_MAIL_TO"]
        missing_vars = [var for var in required_env_vars if not os.getenv(var)]
        if missing_vars:
            raise ValueError(f"缺少必要的环境变量: {', '.join(missing_vars)}")
        
        # 更新环境文件哈希值
        self.env_hash = get_env_file_hash()
    
    def check_and_update(self):
        """检查并更新配置"""
        current_hash = get_env_file_hash()
        if current_hash != self.env_hash:
            print("检测到.env文件变化，重新加载配置...")
            self.update_configs()
            return True
        return False
    
    def _get_repo_configs(self):
        """获取仓库配置"""
        def parse_ignore_patterns(patterns_str):
            return [pat.strip() for pat in patterns_str.split(',') if pat.strip()]
        
        repo_paths = os.getenv('GIT_REPO_PATHS', '/Users/Chen/Notebook').split(';')
        remotes = os.getenv('GIT_REMOTES', 'origin').split(';')
        branches = os.getenv('GIT_BRANCH', 'main').split(';')
        ignore_patterns_list = os.getenv('GIT_IGNORE_PATTERNS', '.git,.DS_Store,.history,.temp.driveupload').split(';')
        
        configs = []
        for i, repo_path in enumerate(repo_paths):
            repo_path = repo_path.strip()
            if repo_path:
                remote = remotes[min(i, len(remotes)-1)].strip()
                branch = branches[min(i, len(branches)-1)].strip()
                patterns_str = ignore_patterns_list[min(i, len(ignore_patterns_list)-1)]
                ignore_patterns = parse_ignore_patterns(patterns_str)
                
                configs.append({
                    "repo_path": repo_path,
                    "branch": branch,
                    "remote": remote,
                    "ignore_patterns": ignore_patterns
                })
        
        return configs

class EmailManager:
    def __init__(self, config_manager):
        self.config_manager = config_manager
        self.last_email_time = 0
        self.error_cache = []
        self.daily_email_count = 0
        self.last_email_date = date.today()
    
    def _reset_daily_count(self):
        current_date = date.today()
        if current_date != self.last_email_date:
            self.daily_email_count = 0
            self.last_email_date = current_date
    
    def can_send_email(self) -> bool:
        self._reset_daily_count()
        current_time = time.time()
        if self.daily_email_count >= self.config_manager.email_config['max_daily_emails']:
            return False
        if not self.config_manager.email_config['enabled']:
            return False
        return (current_time - self.last_email_time) >= self.config_manager.email_config['min_interval']
    
    def add_error(self, error_message: str, repo_path: str):
        self.error_cache.append({
            'timestamp': datetime.now(),
            'repo_path': repo_path,
            'message': error_message
        })
        
        if self.can_send_email():
            self.send_cached_errors()
    
    def send_cached_errors(self):
        if not self.error_cache:
            return
        
        try:
            error_content = "Git推送错误报告：\n\n"
            for error in self.error_cache:
                error_content += f"时间: {error['timestamp']}\n"
                error_content += f"仓库: {error['repo_path']}\n"
                error_content += f"错误信息: {error['message']}\n"
                error_content += "-" * 50 + "\n"
            
            error_content += f"\n今日已发送邮件数: {self.daily_email_count + 1}/{self.config_manager.email_config['max_daily_emails']}"
            
            msg = MIMEText(error_content, 'plain', 'utf-8')
            msg['Subject'] = f'Git推送失败通知 - {Path(self.error_cache[0]["repo_path"]).name}'
            msg['From'] = self.config_manager.email_config['sender_email']
            msg['To'] = self.config_manager.email_config['receiver_email']
            
            server = smtplib.SMTP_SSL(
                self.config_manager.email_config['smtp_server'], 
                self.config_manager.email_config['smtp_port']
            )
            server.login(
                self.config_manager.email_config['sender_email'], 
                self.config_manager.email_config['sender_password']
            )
            server.send_message(msg)
            server.quit()
            
            self.daily_email_count += 1
            self.last_email_time = time.time()
            print(f"错误报告邮件发送成功，包含 {len(self.error_cache)} 条错误信息")
            print(f"今日已发送邮件数: {self.daily_email_count}/{self.config_manager.email_config['max_daily_emails']}")
            
            self.error_cache = []
            
        except Exception as e:
            print(f"发送邮件失败: {str(e)}")

def should_ignore(path: str, ignore_patterns: List[str]) -> bool:
    from fnmatch import fnmatch
    return any(fnmatch(str(path), pattern) for pattern in ignore_patterns)

def get_directory_hash(directory: str, ignore_patterns: List[str]) -> str:
    hash_list = []
    for path in Path(directory).rglob('*'):
        if path.is_file() and not should_ignore(str(path), ignore_patterns):
            file_hash = hashlib.md5(path.read_bytes()).hexdigest()
            hash_list.append(f"{str(path)}:{file_hash}")
    return hashlib.md5(''.join(sorted(hash_list)).encode()).hexdigest()

def git_push(config: Dict, email_manager: EmailManager) -> tuple[bool, str]:
    try:
        os.chdir(config['repo_path'])
        
        status = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True)
        
        if not status.stdout.strip():
            return True, "没有需要推送的变更"
        
        subprocess.run(['git', 'add', '.'], check=True)
        
        commit_message = f"Auto commit at {datetime.now()}"
        subprocess.run(['git', 'commit', '-m', commit_message], check=True)
        
        push_result = subprocess.run(['git', 'push', config['remote'], config['branch']], 
                                   capture_output=True, text=True)
        
        return True, "成功推送文件变更"
        
    except subprocess.CalledProcessError as e:
        error_msg = f"命令执行失败: {str(e)}"
        email_manager.add_error(error_msg, config['repo_path'])
        return False, error_msg
    except Exception as e:
        error_msg = f"未知错误: {str(e)}"
        email_manager.add_error(error_msg, config['repo_path'])
        return False, error_msg

def main():
    config_manager = ConfigManager()
    email_manager = EmailManager(config_manager)
    
    repo_states = {
        config['repo_path']: {
            'last_hash': None,
            'last_push_time': 0
        } for config in config_manager.configs
    }
    
    min_interval = 30  # 最小推送间隔（秒）

    while True:
        try:
            # 检查配置是否发生变化
            if config_manager.check_and_update():
                # 更新repo_states以匹配新的配置
                repo_states = {
                    config['repo_path']: repo_states.get(config['repo_path'], {
                        'last_hash': None,
                        'last_push_time': 0
                    }) for config in config_manager.configs
                }
            
            current_time = time.time()
            
            for config in config_manager.configs:
                repo_path = config['repo_path']
                state = repo_states[repo_path]
                
                current_hash = get_directory_hash(repo_path, config['ignore_patterns'])
                
                if (current_hash != state['last_hash'] and 
                    current_time - state['last_push_time'] >= min_interval):
                    success, message = git_push(config, email_manager)
                    if success:
                        if message != "没有需要推送的变更":
                            state['last_hash'] = current_hash
                            state['last_push_time'] = current_time
                        print(f"仓库 {repo_path} 状态: {message} - {datetime.now()}")
                    else:
                        print(f"仓库 {repo_path} 推送失败: {message} - {datetime.now()}")

            time.sleep(5)
        except KeyboardInterrupt:
            print("程序已停止")
            break
        except Exception as e:
            print(f"发生错误: {str(e)}")
            time.sleep(5)

if __name__ == "__main__":
    main()