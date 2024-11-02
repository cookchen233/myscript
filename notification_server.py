# notification_server.py

import socket
import signal
import sys
import os
import time
import asyncio
from datetime import datetime
import subprocess
import logging
from logging.handlers import RotatingFileHandler
import json
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import discord
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

# 错误级别定义
class ErrorLevel:
    DEBUG = 'debug'
    INFO = 'info'
    ERROR = 'error'

class NotificationConfig:
    def __init__(self):
        self.config = {
        'port': int(os.getenv('NF_PORT', 9123)),
        'buffer_size': int(os.getenv('NF_BUFFER_SIZE', 4096)),
        'pid_file': os.getenv('NF_PID_FILE', '/tmp/notification_server.pid'),
        'log_file': os.getenv('NF_LOG_FILE', 'notification_server.log'),
        'max_log_size': int(os.getenv('NF_MAX_LOG_SIZE', 10 * 1024 * 1024)),  # 10MB
        'backup_count': int(os.getenv('NF_BACKUP_COUNT', 5)),
        
        # 邮件配置
        'smtp_host': os.getenv('NF_SMTP_HOST', 'smtp.example.com'),
        'smtp_port': int(os.getenv('NF_SMTP_PORT', 465)),
        'smtp_user': os.getenv('NF_SMTP_USER', 'user@example.com'),
        'smtp_pass': os.getenv('NF_SMTP_PASS', 'password'),
        'mail_from': os.getenv('NF_MAIL_FROM', 'notification@example.com'),
        'mail_to': os.getenv('NF_MAIL_TO', 'admin@example.com').split(','),
        
        # 通知配置
        'notify_interval': {  # 单位：秒
            ErrorLevel.DEBUG: int(os.getenv('NF_DEBUG_INTERVAL', 300)),
            ErrorLevel.INFO: int(os.getenv('NF_INFO_INTERVAL', 300)),
            ErrorLevel.ERROR: int(os.getenv('NF_ERROR_INTERVAL', 60))
        },
        
        # 通知方式开关
        'enable_sound': os.getenv('NF_ENABLE_SOUND', 'true').lower() == 'true',
        'sound_file': os.getenv('NF_SOUND_FILE', '/System/Library/Sounds/Ping.aiff'),
        'enable_mail': os.getenv('NF_ENABLE_MAIL', 'true').lower() == 'true',
        'enable_discord': os.getenv('NF_ENABLE_DISCORD', 'true').lower() == 'true',
        
        # 声音配置
        'enable_sound': os.getenv('NF_ENABLE_SOUND', 'true').lower() == 'true',
        'sound_file': os.getenv('NF_SOUND_FILE', '/System/Library/Sounds/Ping.aiff'),
        'say_message': os.getenv('NF_SAY_MESSAGE', 'false').lower() == 'true',
        
    }

class NotificationServer:
    def __init__(self):
        # 加载配置
        self.config = NotificationConfig().config
        
        # 初始化日志
        self.setup_logger()
        
        # 检查是否已经运行
        self.check_running()
        
        # 写入PID文件
        with open(self.config['pid_file'], 'w') as f:
            f.write(str(os.getpid()))
        
        # 初始化通知记录
        self.notification_history = {}
        
        # 设置信号处理
        signal.signal(signal.SIGTERM, self.handle_signal)
        signal.signal(signal.SIGINT, self.handle_signal)
        
        # 初始化异步事件循环
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        
        # 初始化Discord客户端
        if self.config['enable_discord']:
            self.discord_client = discord.Client(intents=discord.Intents.default())
            self.discord_channel = None
            self.setup_discord()
        
        # 添加 Discord 重试相关的属性
        self.discord_retry_interval = 3600  # 1小时
        self.discord_last_try = 0
        self.discord_enabled_original = self.config['enable_discord']
    
    def setup_logger(self):
        """配置日志系统"""
        self.logger = logging.getLogger('NotificationServer')
        self.logger.setLevel(logging.DEBUG)
        
        # 文件处理器
        file_handler = RotatingFileHandler(
            self.config['log_file'],
            maxBytes=self.config['max_log_size'],
            backupCount=self.config['backup_count']
        )
        file_handler.setLevel(logging.DEBUG)
        
        # 控制台处理器
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # 设置格式
        formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        # 添加处理器
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
    
    def check_running(self):
        """检查服务是否已经运行"""
        if os.path.exists(self.config['pid_file']):
            with open(self.config['pid_file'], 'r') as f:
                pid = int(f.read().strip())
            try:
                os.kill(pid, 0)
                self.logger.error(f"Server is already running with PID {pid}")
                sys.exit(1)
            except OSError:
                pass

    def handle_signal(self, signum, frame):
        """处理信号"""
        self.logger.info(f"Received signal {signum}")
        self.cleanup()
        sys.exit(0)

    def should_notify(self, error_tag: str, error_level: str, notify_type: str) -> bool:
        """
        判断是否应该发送通知
        
        Args:
            error_tag: 错误标签
            error_level: 错误级别
            notify_type: 通知类型 (sound/mail/discord)
            
        Returns:
            bool: 是否应该发送通知
        """
        if not error_tag:
            return True
            
        current_time = time.time()
        history_key = f"{error_tag}_{notify_type}"
        
        if history_key in self.notification_history:
            last_time = self.notification_history[history_key]
            interval = self.config['notify_interval'].get(error_level, 300)
            
            if current_time - last_time < interval:
                return False
        
        self.notification_history[history_key] = current_time
        return True

    def play_sound(self, message, error_tag, error_level):
        """播放声音通知"""
        if not self.config['enable_sound']:
            return
            
        if not self.should_notify(error_tag, error_level, 'sound'):
            return
            
        try:
            # 播放声音文件
            sound_file = self.config['sound_file']
            if os.path.exists(sound_file):
                if sys.platform == 'darwin':  # macOS
                    subprocess.run(['afplay', sound_file])
                    self.logger.debug(f"Sound effect played for {error_level} message")
            else:
                self.logger.warning(f"Sound file not found: {sound_file}")
                
            # 播放语音消息
            if self.config['say_message'] and sys.platform == 'darwin':
                # 截取前10个字符
                short_message = message[:10]
                subprocess.run(['say', short_message])
                self.logger.debug(f"Voice message played: {short_message}")
                
        except Exception as e:
            self.logger.error(f"Failed to play sound: {e}")

    def send_mail(self, message, error_tag, error_level):
        """发送邮件通知"""
        if not self.config['enable_mail']:
            return
            
        if not self.should_notify(error_tag, error_level, 'mail'):
            return
            
        try:
            msg = MIMEText(message, 'plain', 'utf-8')
            msg['Subject'] = Header(f'[{error_level.upper()}] 系统通知', 'utf-8')
            msg['From'] = self.config['mail_from']
            msg['To'] = ','.join(self.config['mail_to'])
            
            with smtplib.SMTP_SSL(self.config['smtp_host'], self.config['smtp_port']) as smtp:
                smtp.login(self.config['smtp_user'], self.config['smtp_pass'])
                smtp.send_message(msg)
                
            self.logger.debug(f"Mail sent for {error_level} message: {message}")
        except Exception as e:
            self.logger.error(f"Failed to send mail: {e}")

    def setup_discord(self):
        """设置Discord客户端"""
        @self.discord_client.event
        async def on_ready():
            self.discord_channel = self.discord_client.get_channel(
                int(os.getenv('DISCORD_CHANNEL_ID'))
            )
            self.logger.info(f"Discord bot logged in as {self.discord_client.user}")

    async def check_discord_retry(self):
        """检查是否应该重试 Discord 连接"""
        while True:
            try:
                await asyncio.sleep(60)  # 每分钟检查一次
                
                # 如果 Discord 原本就是禁用的，不需要重试
                if not self.discord_enabled_original:
                    continue
                    
                current_time = time.time()
                # 如果 Discord 被临时禁用且距离上次尝试已经超过重试间隔
                if (not self.config['enable_discord'] and 
                    current_time - self.discord_last_try >= self.discord_retry_interval):
                    
                    self.logger.info("Attempting to reconnect Discord...")
                    self.config['enable_discord'] = True
                    self.discord_last_try = current_time
                    
                    try:
                        # 重新初始化 Discord 客户端
                        self.discord_client = discord.Client(intents=discord.Intents.default())
                        self.discord_channel = None
                        self.setup_discord()
                        
                        # 尝试连接
                        await asyncio.wait_for(
                            self.discord_client.start(os.getenv('DISCORD_TOKEN')),
                            timeout=30
                        )
                        self.logger.info("Successfully reconnected to Discord")
                    except Exception as e:
                        self.logger.warning(f"Failed to reconnect to Discord: {e}")
                        self.config['enable_discord'] = False
                        
            except Exception as e:
                self.logger.error(f"Error in Discord retry check: {e}")
                await asyncio.sleep(60)  # 发生错误时等待一分钟再继续

    async def discord_start(self):
        """异步启动Discord客户端"""
        if self.config['enable_discord']:
            try:
                self.discord_last_try = time.time()
                await asyncio.wait_for(
                    self.discord_client.start(os.getenv('DISCORD_TOKEN')),
                    timeout=30
                )
            except asyncio.TimeoutError:
                self.logger.warning("Discord connection timed out - will retry in 1 hour")
                self.config['enable_discord'] = False
            except Exception as e:
                self.logger.warning(f"Failed to initialize Discord: {e} - will retry in 1 hour")
                self.config['enable_discord'] = False

    async def send_discord(self, message, error_tag, error_level):
        """发送Discord通知"""
        if not self.config['enable_discord']:
            return
            
        if not self.should_notify(error_tag, error_level, 'discord'):
            return
            
        try:
            if self.discord_channel:
                await self.discord_channel.send(f"[{error_level.upper()}] {message}")
                self.logger.debug(f"Discord message sent for {error_level} message: {message}")
        except Exception as e:
            self.logger.error(f"Failed to send Discord message: {e}")

    async def process_message(self, message):
        """处理接收到的消息"""
        try:
            data = json.loads(message)
            error_tag = str(data.get('error_tag', ''))
            error_level = data.get('error_level', 'info').lower()
            message = data.get('message', message)
            
            if error_level not in [ErrorLevel.DEBUG, ErrorLevel.INFO, ErrorLevel.ERROR]:
                error_level = ErrorLevel.INFO
                
        except json.JSONDecodeError:
            error_tag = ''
            error_level = ErrorLevel.INFO
        
        self.logger.info(f"Tag: {error_tag}, Level: {error_level}, Message: {message}")
        
        # 发送通知
        self.play_sound(message, error_tag, error_level)
        self.send_mail(message, error_tag, error_level)
        await self.send_discord(message, error_tag, error_level)

    async def handle_client(self, reader, writer):
        """处理客户端连接"""
        try:
            data = await reader.read(self.config['buffer_size'])
            if data:
                message = data.decode('utf-8').strip()
                await self.process_message(message)
        except Exception as e:
            self.logger.error(f"Error handling client: {e}")
        finally:
            writer.close()
            await writer.wait_closed()

    async def run_server(self):
        """运行服务器"""
        server = await asyncio.start_server(
            self.handle_client,
            '0.0.0.0',
            self.config['port']
        )
        
        self.logger.info(f"Notification server listening on port {self.config['port']}...")
        
        async with server:
            await server.serve_forever()

    def run(self):
        """启动服务器"""
        try:
            async def main():
                tasks = []
                if self.config['enable_discord']:
                    discord_task = self.loop.create_task(self.discord_start())
                    tasks.append(discord_task)
                
                # 添加 Discord 重试检查任务
                retry_task = self.loop.create_task(self.check_discord_retry())
                tasks.append(retry_task)
                
                server_task = self.loop.create_task(self.run_server())
                tasks.append(server_task)
                
                # 等待所有任务完成，忽略已取消的任务
                done, pending = await asyncio.wait(
                    tasks,
                    return_when=asyncio.FIRST_EXCEPTION
                )
                
                # 检查是否有任务出错
                for task in done:
                    try:
                        task.result()
                    except asyncio.CancelledError:
                        pass
                    except Exception as e:
                        if task not in [discord_task, retry_task]:  # 如果不是Discord相关任务出错
                            raise  # 重新抛出异常
                
                # 取消所有未完成的任务
                for task in pending:
                    task.cancel()
                    try:
                        await task
                    except asyncio.CancelledError:
                        pass

            self.loop.run_until_complete(main())

        except Exception as e:
            self.logger.error(f"Server error: {e}")
            self.cleanup()
            sys.exit(1)
        finally:
            self.cleanup()
            self.loop.close()

    def cleanup(self):
        """清理资源"""
        if hasattr(self, 'loop') and self.loop.is_running():
            for task in asyncio.all_tasks(self.loop):
                task.cancel()
        if hasattr(self, 'discord_client') and self.discord_client and self.discord_client.is_ready():
            self.loop.run_until_complete(self.discord_client.close())
        try:
            os.remove(self.config['pid_file'])
        except OSError:
            pass

def main():
    server = NotificationServer()
    server.run()

if __name__ == '__main__':
    main()