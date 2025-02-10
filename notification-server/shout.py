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

def clean_text(text):
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
    
def text_to_speech(text,
                   output_file="output.wav", 
                   speaker_id="p243",  # 可以尝试不同说话人
                   speed=1.2,          # 略微提高速度
                   pitch=1.7,          # 提高音调使声音更尖锐
                   noise_scale=0.3,    # 降低噪声使声音更清晰
                   noise_scale_w=0.4,  # 降低噪声变化
                   emotion="angry",    # 愤怒情绪本身声音较为尖锐
                   style="seductive",
                   autoplay=True,
                   blocking=False):
    """
    将文本转换为语音
    """
    def generate():
        cleaned_text = clean_text(text)
        _tts.tts_to_file(
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