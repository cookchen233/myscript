#!/usr/bin/env python3
import sys
import os
from threading import Thread
import subprocess

# 全局初始化 TTS
os.environ['PATH'] = '/Users/Chen/Library/Python/3.9/bin:' + os.environ['PATH']
from TTS.api import TTS
import logging

# 全局 TTS 实例
_tts = TTS(model_name="tts_models/en/vctk/vits", progress_bar=False, gpu=False)
logging.getLogger('TTS').setLevel(logging.WARNING)
_tts.synthesizer.tts_config.audio["do_trim_silence"] = False
_tts.synthesizer.tts_config.audio["do_sound_norm"] = False

def play_audio(output_file):
    """非阻塞播放音频"""
    if os.name == 'nt':
        subprocess.Popen(['start', output_file], shell=True)
    else:
        if sys.platform == "darwin":
            # subprocess.Popen(['afplay', '-r', "1.25", output_file])
            subprocess.Popen(['afplay', output_file])
        else:
            if subprocess.call(['which', 'mpg321'], stdout=subprocess.DEVNULL) == 0:
                subprocess.Popen(['mpg321', output_file])
            else:
                subprocess.Popen(['aplay', output_file])

def text_to_speech(text, 
                   output_file="output.wav",
                   speaker_id="p227",
                   speed=1.0,
                   pitch=1.3,
                   noise_scale=0.8,
                   noise_scale_w=1.0,
                   emotion="happy",
                   style="seductive",
                   autoplay=True,
                   blocking=False):
    """
    将文本转换为语音
    """
    def generate():
        _tts.tts_to_file(
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
        if autoplay:
            play_audio(output_file)
    
    if blocking:
        generate()
    else:
        Thread(target=generate).start()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: pitch_test.py <text_to_speak>")
        sys.exit(1)
        
    text_to_speak = " ".join(sys.argv[1:])
    text_to_speech(text_to_speak, blocking=False)
    print("继续执行其他代码...")