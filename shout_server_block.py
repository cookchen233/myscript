#!/usr/bin/env python3
import sys
import os
import socket
import json
from threading import Thread, Lock
import subprocess
import signal
import queue

# 全局初始化 TTS
os.environ['PATH'] = '/Users/Chen/Library/Python/3.9/bin:' + os.environ['PATH']
from TTS.api import TTS
import logging

SOCKET_PATH = '/tmp/shout_service.sock'

class ShoutServer:
    def __init__(self):
        # 初始化 TTS
        self.tts = TTS(model_name="tts_models/en/vctk/vits", progress_bar=False, gpu=False)
        logging.getLogger('TTS').setLevel(logging.WARNING)
        self.tts.synthesizer.tts_config.audio["do_trim_silence"] = False
        self.tts.synthesizer.tts_config.audio["do_sound_norm"] = False
        
        # 语音队列
        self.speech_queue = queue.Queue()
        # 正在播放的标志
        self.is_playing = False
        self.play_lock = Lock()
        
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            if os.path.exists(SOCKET_PATH):
                raise

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o777)
        self.sock.listen(1)
        
        signal.signal(signal.SIGINT, self.cleanup)
        signal.signal(signal.SIGTERM, self.cleanup)

        # 启动队列处理线程
        Thread(target=self.process_queue, daemon=True).start()

    def play_audio(self, output_file):
        if sys.platform == "darwin":
            process = subprocess.Popen(['afplay', output_file])
            process.wait()  # 等待播放完成
    
    def clean_text(self, text):
        # 定义要替换为空格的特殊字符
        special_chars = [
            '\\', '/', '::', '->', '=>', '<=>', '<-', '<', '>', 
            '{', '}', '[', ']', '|', '&&', '||', '^', '$', '#',
            '!=', '==', '===', '!==', '+=', '-=', '*=', '/=',
            '++', '--', '**', '//', '/*', '*/', '@', '&',
            ';', '`', '_'
        ]
        
        cleaned_text = text
        # 替换特殊字符
        for char in special_chars:
            cleaned_text = cleaned_text.replace(char, ' ')
        
        # 替换数字为空格
        cleaned_text = ''.join(' ' if c.isdigit() else c for c in cleaned_text)
        
        # 移除多余的空格
        cleaned_text = ' '.join(cleaned_text.split())
        
        return cleaned_text

    def text_to_speech(
            self, 
            text, 
            conn, 
            output_file="output.wav", 
            speaker_id="p243",
            speed=1.2,          # 略微提高速度
            pitch=1.7,          # 提高音调使声音更尖锐
            noise_scale=0.3,    # 降低噪声使声音更清晰
            noise_scale_w=0.4,  # 降低噪声变化
            emotion="angry",    # 愤怒情绪本身声音较为尖锐
            style="seductive"
            ):
        with self.play_lock:
            cleaned_text = self.clean_text(text)
            self.tts.tts_to_file(
                text=cleaned_text,
                speaker=speaker_id,
                file_path=output_file,
                emotion=emotion,
                style=style,
                speed=speed,
                pitch=pitch,
                noise_scale=noise_scale,
                noise_scale_w=noise_scale_w
            )
            self.play_audio(output_file)
            conn.send(b'{"status": "completed"}')

    def process_queue(self):
        while True:
            try:
                text, conn = self.speech_queue.get()
                self.text_to_speech(text, conn)
                self.speech_queue.task_done()
            except Exception as e:
                print(f"Error processing queue: {e}")

    def handle_client(self, conn):
        try:
            data = conn.recv(4096)
            if not data:
                return
            
            try:
                request = json.loads(data.decode('utf-8'))
                text = request.get('text', '')
                if text:
                    # 将请求加入队列
                    self.speech_queue.put((text, conn))
                else:
                    conn.send(b'{"status": "error", "message": "No text provided"}')
            except json.JSONDecodeError:
                conn.send(b'{"status": "error", "message": "Invalid JSON"}')
        except Exception as e:
            print(f"Error handling client: {e}")
        finally:
            # 注意：不要在这里关闭连接，因为我们需要等待播放完成后发送响应
            pass

    def run(self):
        print(f"Server starting on {SOCKET_PATH}")
        while True:
            conn, addr = self.sock.accept()
            Thread(target=self.handle_client, args=(conn,)).start()

    def cleanup(self, signum, frame):
        print("\nCleaning up...")
        self.sock.close()
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            pass
        sys.exit(0)

if __name__ == "__main__":
    server = ShoutServer()
    server.run()