import socket
import signal
import sys
import os
import time
from datetime import datetime
import subprocess
import logging
from logging.handlers import RotatingFileHandler

class ErrorSoundServer:
    """
    the client:
    import socket
    import logging

    def play_error_sound(message):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(1)  # 1秒超时
                sock.connect(('10.211.55.2', 9123))
                sock.send(message.encode('utf-8'))
            return True
        except Exception as e:
            logging.error(f"Server playErrorSound connection failed: {e}")
            return False
            
    usage: python ~/Coding/myscript/play_error_sound.py 1 >/dev/null 2>&1 &
    """
    def __init__(self):
        self.config = {
            'port': 9123,
            'log_file': os.path.join(os.path.dirname(__file__), 'play_error_sound.log'),
            'max_log_size': 10 * 1024 * 1024,  # 10MB
            'max_log_backup': 3,
            'enable_sound': True,
            'sound_file': '/System/Library/Sounds/Ping.aiff',
            'buffer_size': 2048,
            'pid_file': os.path.join(os.path.dirname(__file__), 'play_error_sound.pid'),
        }
        
        self.setup_logging()
        self.sock = None
        self.setup_signal_handlers()
        self.write_pid_file()

    def setup_logging(self):
        handler = RotatingFileHandler(
            self.config['log_file'],
            maxBytes=self.config['max_log_size'],
            backupCount=self.config['max_log_backup']
        )
        formatter = logging.Formatter('%(asctime)s - %(message)s')
        handler.setFormatter(formatter)
        
        self.logger = logging.getLogger('ErrorSoundServer')
        self.logger.setLevel(logging.INFO)
        self.logger.addHandler(handler)

    def setup_signal_handlers(self):
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGHUP, self.signal_handler)

    def signal_handler(self, signum, frame):
        self.cleanup()
        sys.exit(0)

    def write_pid_file(self):
        with open(self.config['pid_file'], 'w') as f:
            f.write(str(os.getpid()))

    def cleanup(self):
        if self.sock:
            self.sock.close()
        try:
            os.remove(self.config['pid_file'])
        except OSError:
            pass

    def play_sound(self):
        if self.config['enable_sound']:
            try:
                subprocess.Popen(['afplay', self.config['sound_file']], 
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL)
            except Exception as e:
                self.logger.error(f"Failed to play sound: {e}")

    def run(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.bind(('0.0.0.0', self.config['port']))
            self.sock.listen(5)
            self.sock.setblocking(False)
            
            self.logger.info(f"Listening on port {self.config['port']}...")
            
            while True:
                try:
                    conn, addr = self.sock.accept()
                    try:
                        data = conn.recv(self.config['buffer_size'])
                        if data:
                            message = data.decode('utf-8').strip()
                            self.logger.info(message)
                            self.play_sound()
                    finally:
                        conn.close()
                except BlockingIOError:
                    time.sleep(0.1)  # 避免CPU占用过高
                except Exception as e:
                    self.logger.error(f"Error handling connection: {e}")

        except Exception as e:
            self.logger.error(f"Server error: {e}")
            self.cleanup()
            sys.exit(1)

def main():
    server = ErrorSoundServer()
    server.run()

if __name__ == '__main__':
    main()