#!/usr/bin/env python3
import sys
import os
import socket
import json
from threading import Thread
import subprocess
import signal

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
        
        # 确保socket文件不存在
        try:
            os.unlink(SOCKET_PATH)
        except OSError:
            if os.path.exists(SOCKET_PATH):
                raise

        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.bind(SOCKET_PATH)
        os.chmod(SOCKET_PATH, 0o777)  # 确保PHP能访问socket
        self.sock.listen(1)
        
        # 注册信号处理
        signal.signal(signal.SIGINT, self.cleanup)
        signal.signal(signal.SIGTERM, self.cleanup)

    def play_audio(self, output_file):
        if sys.platform == "darwin":
            subprocess.Popen(['afplay', output_file])

    def text_to_speech(self, text, output_file="output.wav", speaker_id="p227",
                      speed=1.0, pitch=1.3, noise_scale=0.8, noise_scale_w=1.0,
                      emotion="happy", style="seductive"):
        def generate():
            self.tts.tts_to_file(
                text=text,
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
        
        Thread(target=generate).start()

    def handle_client(self, conn):
        while True:
            try:
                data = conn.recv(4096)
                if not data:
                    break
                
                try:
                    request = json.loads(data.decode('utf-8'))
                    text = request.get('text', '')
                    if text:
                        self.text_to_speech(text)
                        conn.send(b'{"status": "success"}')
                    else:
                        conn.send(b'{"status": "error", "message": "No text provided"}')
                except json.JSONDecodeError:
                    conn.send(b'{"status": "error", "message": "Invalid JSON"}')
            except Exception as e:
                print(f"Error handling client: {e}")
                break
        conn.close()

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