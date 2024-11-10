# notification_client.py

import socket
import json
import logging
from typing import Optional

def send_notification(message: str, error_tag: Optional[str] = None, error_level: str = 'info') -> bool:
    """
    发送通知到服务端
    
    Args:
        message: 通知消息
        error_tag: 错误标签,用于去重
        error_level: 错误级别 debug/info/error
            
    Returns:
        bool: 是否发送成功
    
    Examples:
        # 调试信息
        send_notification("调试信息", "DEBUG_001", "debug")
        
        # 普通信息
        send_notification("普通信息", "INFO_001", "info")
        
        # 错误信息 
        send_notification("错误信息", "ERR_001", "error")
        
        # 不带error_tag,每次都会触发通知
        send_notification("临时通知", error_level="info")
    """
    try:
        data = {
            'message': message,
            'error_level': error_level
        }
        if error_tag is not None:
            data['error_tag'] = error_tag
            
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            sock.connect(('127.0.0.1', 9123))
            sock.send(json.dumps(data).encode('utf-8'))
        return True
    except Exception as e:
        logging.error(f"Server notification connection failed: {e}")
        return False

# 使用示例
if __name__ == '__main__':
    # 配置日志
    logging.basicConfig(level=logging.INFO)
    
    # 发送各种级别的通知
    send_notification("这是一条调试信息", "DEBUG_001", "debug")
    send_notification("这是一条普通信息", "INFO_001", "info")
    send_notification("这是一条错误信息", "ERR_001", "error")
    
    # 不带error_tag的通知
    send_notification("这是一条临时通知")