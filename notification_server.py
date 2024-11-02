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
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import aiohttp
import asyncio
from aiohttp_socks import ProxyConnector

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
        'log_file': os.getenv('NF_LOG_FILE', './notification_server.log'),
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
        
        'proxy_settings': {
            'https': os.getenv('NF_HTTPS_PROXY', 'http://127.0.0.1:8001'),
            'http': os.getenv('NF_HTTP_PROXY', 'http://127.0.0.1:8001'),
            'socks': os.getenv('NF_SOCKS_PROXY', 'socks5://127.0.0.1:1081')
        },
        'enable_proxy': os.getenv('NF_ENABLE_PROXY', 'false').lower() == 'true',
    }

class EnvFileHandler(FileSystemEventHandler):
    def __init__(self, server):
        self.server = server
        self.last_reload = 0
        self.reload_interval = 1  # 最小重载间隔(秒)

    def on_modified(self, event):
        if event.src_path.endswith('.env'):
            current_time = time.time()
            if current_time - self.last_reload >= self.reload_interval:
                self.last_reload = current_time
                self.server.reload_config()

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
        signal.signal(signal.SIGHUP, self.handle_signal)
        
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
        
        # 添加env文件监控
        self.setup_env_monitor()
        self.logger.info("xxx Discord event handlers...")


    def setup_env_monitor(self):
        """设置.env文件监控"""
        self.env_observer = Observer()
        handler = EnvFileHandler(self)
        
        # 获取.env文件所在目录
        env_dir = os.path.dirname(os.path.abspath('.env'))
        self.env_observer.schedule(handler, env_dir, recursive=False)
        self.env_observer.start()
        self.logger.info("Started monitoring .env file for changes")
            
    # 在 reload_config 方法中修改:
    def reload_config(self):
        """重新加载配置"""
        try:
            self.logger.info("Reloading configuration from .env file...")
            
            # 重新加载环境变量
            load_dotenv(override=True)
            
            # 更新配置
            new_config = NotificationConfig().config
            
            # 需要重启服务的配置项
            restart_required = ['port', 'buffer_size']
            
            # 检查是否需要重启
            need_restart = any(
                self.config[key] != new_config[key] 
                for key in restart_required
            )
            
            # 更新配置
            old_config = self.config.copy()
            self.config.update(new_config)
            
            # 处理Discord配置变化
            if (old_config['enable_discord'] != new_config['enable_discord'] or
                os.getenv('NF_DISCORD_TOKEN') != self.discord_client._connection.token):
                # 使用 asyncio.run_coroutine_threadsafe 在事件循环中运行异步函数
                future = asyncio.run_coroutine_threadsafe(
                    self.handle_discord_config_change(),
                    self.loop
                )
                # 等待异步操作完成
                future.result()
                
            if need_restart:
                self.logger.info("Configuration changes require server restart")
                # 发送重启信号
                os.kill(os.getpid(), signal.SIGHUP)
            else:
                self.logger.info("Configuration reloaded successfully")
                
        except Exception as e:
            self.logger.error(f"Failed to reload configuration: {e}")
            # 还原配置
            self.config = old_config

    async def handle_discord_config_change(self):
        """处理Discord配置变化"""
        try:
            # 如果Discord客户端已连接,先断开
            if self.discord_client and not self.discord_client.is_closed():
                await self.discord_client.close()
                
            # 如果启用Discord
            if self.config['enable_discord']:
                self.discord_client = discord.Client(intents=discord.Intents.default())
                self.discord_channel = None
                self.setup_discord()
                await self.discord_start()
            else:
                self.discord_client = None
                self.discord_channel = None
                
        except Exception as e:
            self.logger.error(f"Failed to handle Discord config change: {e}")
    
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
        if signum == signal.SIGHUP:
            self.logger.info("Received SIGHUP signal, restarting server...")
            self.restart_server()
        else:
            self.logger.info(f"Received signal {signum}")
            self.cleanup()
            sys.exit(0)

    def restart_server(self):
        """重启服务器"""
        try:
            self.cleanup()
            os.execv(sys.executable, [sys.executable] + sys.argv)
        except Exception as e:
            self.logger.error(f"Failed to restart server: {e}")
            sys.exit(1)

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
        self.logger.info("Setting up Discord client...")
        
        @self.discord_client.event
        async def on_ready():
            try:
                channel_id = os.getenv('NF_DISCORD_CHANNEL_ID')
                if not channel_id:
                    self.logger.error("NF_DISCORD_CHANNEL_ID not set in environment variables")
                    return
                    
                self.logger.info(f"Attempting to get channel with ID: {channel_id}")
                
                # 添加所有可用频道的日志
                all_channels = self.discord_client.get_all_channels()
                self.logger.info("Available channels:")
                for channel in all_channels:
                    self.logger.info(f"- Channel: {channel.name} (ID: {channel.id})")
                
                self.discord_channel = self.discord_client.get_channel(int(channel_id))
                
                if self.discord_channel:
                    self.logger.info(f"Successfully connected to channel: {self.discord_channel.name}")
                else:
                    self.logger.error(f"Could not find channel with ID: {channel_id}")
                    self.logger.info("Please check:")
                    self.logger.info("1. The channel ID is correct")
                    self.logger.info("2. The bot has access to the channel")
                    self.logger.info("3. The bot has the required permissions")
                    
            except ValueError as e:
                self.logger.error(f"Invalid channel ID format: {e}")
            except Exception as e:
                self.logger.error(f"Error in on_ready: {e}", exc_info=True)

    
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
                            self.discord_client.start(os.getenv('NF_DISCORD_TOKEN')),
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
                self.logger.info("Starting Discord client...")
                self.discord_last_try = time.time()
                
                token = os.getenv('NF_DISCORD_TOKEN')
                channel_id = os.getenv('NF_DISCORD_CHANNEL_ID')
                
                # 验证配置
                if not token:
                    raise ValueError("Discord token not found in environment variables")
                if not channel_id:
                    raise ValueError("Discord channel ID not found in environment variables")
                    
                self.logger.info(f"Using token: {token[:10]}... and channel ID: {channel_id}")
                
                # 设置代理
                if self.config['enable_proxy']:
                    # 设置环境变量代理
                    os.environ['https_proxy'] = self.config['proxy_settings']['https']
                    os.environ['http_proxy'] = self.config['proxy_settings']['http']
                    
                    # 创建代理连接器
                    connector = aiohttp.TCPConnector(
                        ssl=False,
                        force_close=True,
                        enable_cleanup_closed=True,
                        ttl_dns_cache=300
                    )
                    
                    # 创建自定义session with proxy
                    proxy_url = self.config['proxy_settings']['https']
                    proxy_session = aiohttp.ClientSession(
                        connector=connector,
                        timeout=aiohttp.ClientTimeout(total=30),
                        headers={
                            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                        }
                    )
                    
                    # 使用自定义session创建Discord客户端
                    self.discord_client = discord.Client(
                        intents=discord.Intents.default(),
                        proxy=proxy_url,
                        http_session=proxy_session
                    )
                    
                    self.logger.info(f"Using HTTP(S) proxy: {proxy_url}")
                else:
                    self.discord_client = discord.Client(intents=discord.Intents.default())
                
                # 确保客户端已设置事件处理程序
                self.setup_discord()
                
                # 尝试连接，增加超时时间
                self.logger.info("Attempting to connect to Discord...")
                try:
                    await asyncio.wait_for(
                        self.discord_client.start(token),
                        timeout=60  # 增加超时时间到60秒
                    )
                except asyncio.TimeoutError:
                    self.logger.error("Discord connection timed out")
                    raise
                except Exception as e:
                    self.logger.error(f"Discord connection failed: {e}")
                    raise
                
                # 等待并验证频道连接
                retry_count = 0
                max_retries = 5
                retry_delay = 2  # seconds
                
                while not self.discord_channel and retry_count < max_retries:
                    self.logger.info(f"Attempting to get channel {channel_id}, attempt {retry_count + 1}/{max_retries}")
                    
                    try:
                        self.discord_channel = self.discord_client.get_channel(int(channel_id))
                        
                        if self.discord_channel:
                            self.logger.info(f"Successfully connected to channel: {self.discord_channel.name}")
                            break
                            
                        self.logger.warning(f"Channel not found, retrying in {retry_delay} seconds...")
                        await asyncio.sleep(retry_delay)
                        retry_count += 1
                    except Exception as e:
                        self.logger.error(f"Error getting channel: {e}")
                        await asyncio.sleep(retry_delay)
                        retry_count += 1
                        
                if not self.discord_channel:
                    raise Exception(f"Failed to get Discord channel after {max_retries} attempts")
                    
                self.logger.info("Discord connection established successfully")
                
            except Exception as e:
                self.logger.error(f"Failed to initialize Discord: {e}", exc_info=True)
                self.config['enable_discord'] = False
                # 清理资源
                if hasattr(self, 'discord_client') and hasattr(self.discord_client, 'http_session'):
                    try:
                        await self.discord_client.http_session.close()
                    except Exception as e:
                        self.logger.error(f"Error closing Discord session: {e}")
                        
                                 
    async def send_discord(self, message, error_tag, error_level):
        """发送Discord通知"""
        if not self.config['enable_discord']:
            return
            
        if not self.should_notify(error_tag, error_level, 'discord'):
            return
            
        try:
            # 检查客户端状态
            if not self.discord_client or not self.discord_client.is_ready():
                self.logger.warning("Discord client not ready, attempting to reconnect...")
                await self.discord_start()
                
            # 尝试重新获取频道
            if not self.discord_channel:
                channel_id = os.getenv('NF_DISCORD_CHANNEL_ID')
                self.discord_channel = self.discord_client.get_channel(int(channel_id))
                
            if self.discord_channel:
                await self.discord_channel.send(f"[{error_level.upper()}] {message}")
                self.logger.debug(f"Discord message sent for {error_level} message: {message}")
            else:
                raise Exception("Discord channel not available")
                
        except Exception as e:
            self.logger.error(f"Failed to send Discord message: {e}", exc_info=True)
            self.config['enable_discord'] = False  # 临时禁用Discord
        
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
                
                # Discord 相关任务
                if self.config['enable_discord']:
                    self.logger.info("Initializing Discord tasks...")  # 添加这行
                    discord_task = self.loop.create_task(self.discord_start())
                    tasks.append(discord_task)
                    retry_task = self.loop.create_task(self.check_discord_retry())
                    tasks.append(retry_task)
                
                self.logger.info("Starting server task...")  # 添加这行
                server_task = self.loop.create_task(self.run_server())
                tasks.append(server_task)
                
                try:
                    # 等待所有任务完成
                    done, pending = await asyncio.wait(
                        tasks,
                        return_when=asyncio.FIRST_EXCEPTION
                    )
                    
                    # 检查是否有任务出错
                    for task in done:
                        if task.exception():
                            self.logger.error(f"Task failed with error: {task.exception()}")
                            if task == server_task:  # 如果是服务器任务失败，需要重新抛出
                                raise task.exception()
                    
                finally:
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
        # 停止env文件监控
        if hasattr(self, 'env_observer'):
            self.env_observer.stop()
            self.env_observer.join()
        
        # 清理Discord资源
        if hasattr(self, 'discord_client'):
            if hasattr(self.discord_client, 'http_session'):
                try:
                    self.loop.run_until_complete(self.discord_client.http_session.close())
                except Exception as e:
                    self.logger.error(f"Error closing Discord session: {e}")
            if self.discord_client and not self.discord_client.is_closed():
                try:
                    self.loop.run_until_complete(self.discord_client.close())
                except Exception as e:
                    self.logger.error(f"Error closing Discord client: {e}")
        
        # 清理事件循环任务
        if hasattr(self, 'loop') and self.loop.is_running():
            for task in asyncio.all_tasks(self.loop):
                task.cancel()
                try:
                    self.loop.run_until_complete(task)
                except asyncio.CancelledError:
                    pass
        
        # 删除PID文件
        try:
            os.remove(self.config['pid_file'])
        except OSError:
            pass

def main():
    # 设置SIGHUP信号处理
    signal.signal(signal.SIGHUP, lambda signum, frame: None)
    
    server = NotificationServer()
    server.run()

if __name__ == '__main__':
    main()