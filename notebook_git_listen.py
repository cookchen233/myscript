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


import os
from dotenv import load_dotenv

load_dotenv()

def parse_ignore_patterns(patterns_str):
    """解析忽略模式字符串，支持分号分隔的多组模式"""
    return [pat.strip() for pat in patterns_str.split(',') if pat.strip()]

def get_repo_configs():
    # 从环境变量读取仓库路径列表
    repo_paths = os.getenv('GIT_REPO_PATHS', '/Users/Chen/Notebooks').split(';')
    
    # 从环境变量读取远程仓库列表
    remotes = os.getenv('GIT_REMOTES', 'origin').split(';')
    branches = os.getenv('GIT_BRANCH', 'main').split(';')
    
    # 从环境变量读取忽略模式列表，使用分号分隔不同仓库的配置
    ignore_patterns_list = os.getenv('GIT_IGNORE_PATTERNS', '.git,.DS_Store,.history,.temp.driveupload').split(';')
    
    # 构建配置列表
    configs = []
    for i, repo_path in enumerate(repo_paths):
        repo_path = repo_path.strip()
        if repo_path:
            # 获取对应的remote，如果索引超出范围则使用最后一个
            remote = remotes[min(i, len(remotes)-1)].strip()
            branch = branches[min(i, len(branches)-1)].strip()
            
            # 获取对应的ignore_patterns，如果索引超出范围则使用最后一个
            patterns_str = ignore_patterns_list[min(i, len(ignore_patterns_list)-1)]
            ignore_patterns = parse_ignore_patterns(patterns_str)
            
            configs.append({
                "repo_path": repo_path,
                "branch": branch,
                "remote": remote,
                "ignore_patterns": ignore_patterns
            })
    
    return configs

CONFIGS = get_repo_configs()

# 邮件配置
EMAIL_CONFIG = {
    "smtp_server": os.getenv("SMTP_SERVER", "smtp.gmail.com"),
    "smtp_port": int(os.getenv("SMTP_PORT", "587")),
    "sender_email": os.getenv("SENDER_EMAIL"),
    "sender_password": os.getenv("SENDER_PASSWORD"),
    "receiver_email": os.getenv("RECEIVER_EMAIL"),
    "min_interval": 3600,  # 两次邮件之间的最小间隔（秒）
    "max_daily_emails": 3  # 每天最大发送次数
}

# 验证必要的环境变量是否存在
required_env_vars = ["SENDER_EMAIL", "SENDER_PASSWORD", "RECEIVER_EMAIL"]
missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    raise ValueError(f"缺少必要的环境变量: {', '.join(missing_vars)}")

class EmailManager:
    def __init__(self):
        self.last_email_time = 0
        self.error_cache = []  # 用于缓存错误信息
        self.daily_email_count = 0  # 当天已发送的邮件数量
        self.last_email_date = date.today()  # 上次发送邮件的日期
    
    def _reset_daily_count(self):
        """重置每日邮件计数"""
        current_date = date.today()
        if current_date != self.last_email_date:
            self.daily_email_count = 0
            self.last_email_date = current_date
    
    def can_send_email(self) -> bool:
        """检查是否可以发送邮件"""
        self._reset_daily_count()
        current_time = time.time()
        
        # 检查是否超过每日最大发送次数
        if self.daily_email_count >= EMAIL_CONFIG['max_daily_emails']:
            return False
        
        # 检查是否满足最小时间间隔
        return (current_time - self.last_email_time) >= EMAIL_CONFIG['min_interval']
    
    def add_error(self, error_message: str, repo_path: str):
        """添加错误到缓存"""
        self.error_cache.append({
            'timestamp': datetime.now(),
            'repo_path': repo_path,
            'message': error_message
        })
        
        # 如果可以发送邮件，则发送所有缓存的错误
        if self.can_send_email():
            self.send_cached_errors()
    
    def send_cached_errors(self):
        """发送缓存的所有错误"""
        if not self.error_cache:
            return
        
        try:
            # 构建邮件内容
            error_content = "Git推送错误报告：\n\n"
            for error in self.error_cache:
                error_content += f"时间: {error['timestamp']}\n"
                error_content += f"仓库: {error['repo_path']}\n"
                error_content += f"错误信息: {error['message']}\n"
                error_content += "-" * 50 + "\n"
            
            # 添加邮件发送统计信息
            error_content += f"\n今日已发送邮件数: {self.daily_email_count + 1}/{EMAIL_CONFIG['max_daily_emails']}"
            
            msg = MIMEText(error_content, 'plain', 'utf-8')
            msg['Subject'] = f'Git推送失败通知 - {Path(self.error_cache[0]["repo_path"]).name}'
            msg['From'] = EMAIL_CONFIG['sender_email']
            msg['To'] = EMAIL_CONFIG['receiver_email']
            

            # 发送邮件
            server = smtplib.SMTP_SSL(EMAIL_CONFIG['smtp_server'], EMAIL_CONFIG['smtp_port'])
            server.login(EMAIL_CONFIG['sender_email'], EMAIL_CONFIG['sender_password'])
            server.send_message(msg)
            server.quit()
            
            self.daily_email_count += 1
            self.last_email_time = time.time()
            print(f"错误报告邮件发送成功，包含 {len(self.error_cache)} 条错误信息")
            print(f"今日已发送邮件数: {self.daily_email_count}/{EMAIL_CONFIG['max_daily_emails']}")
            
            # 清空错误缓存
            self.error_cache = []
            
        except Exception as e:
            print(f"发送邮件失败: {str(e)}")

def should_ignore(path: str, ignore_patterns: List[str]) -> bool:
    """检查文件是否应该被忽略"""
    from fnmatch import fnmatch
    return any(fnmatch(str(path), pattern) for pattern in ignore_patterns)

def get_directory_hash(directory: str, ignore_patterns: List[str]) -> str:
    """计算目录下所有文件的哈希值"""
    hash_list = []
    for path in Path(directory).rglob('*'):
        if path.is_file() and not should_ignore(str(path), ignore_patterns):
            file_hash = hashlib.md5(path.read_bytes()).hexdigest()
            hash_list.append(f"{str(path)}:{file_hash}")
    return hashlib.md5(''.join(sorted(hash_list)).encode()).hexdigest()

def git_push(config: Dict, email_manager: EmailManager) -> tuple[bool, str]:
    """
    执行git push操作
    返回值: (是否成功, 状态消息)
    """
    try:
        # 进入git仓库目录
        os.chdir(config['repo_path'])
        
        # 检查是否有变更
        status = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True)
        
        if not status.stdout.strip():
            return True, "没有需要推送的变更"
        
        # 添加所有变更
        subprocess.run(['git', 'add', '.'], check=True)
        
        # 提交变更
        commit_message = f"Auto commit at {datetime.now()}"
        subprocess.run(['git', 'commit', '-m', commit_message], check=True)
        
        # 推送到远程
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
    # 初始化邮件管理器
    email_manager = EmailManager()
    
    # 为每个仓库初始化状态
    repo_states = {
        config['repo_path']: {
            'last_hash': None,
            'last_push_time': 0
        } for config in CONFIGS
    }
    
    min_interval = 30  # 最小推送间隔（秒）

    while True:
        try:
            current_time = time.time()
            
            # 遍历所有配置的仓库
            for config in CONFIGS:
                repo_path = config['repo_path']
                state = repo_states[repo_path]
                
                # 计算当前哈希
                current_hash = get_directory_hash(repo_path, config['ignore_patterns'])
                
                # 检查是否有文件变更且满足最小时间间隔
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

            time.sleep(20)
        except KeyboardInterrupt:
            print("程序已停止")
            break
        except Exception as e:
            print(f"发生错误: {str(e)}")
            time.sleep(20)

if __name__ == "__main__":
    main()