#!/usr/bin/python3

def process_text(file_path, output_path):
    def char_type(c):
        if c.isascii():
            return 'english'
        else:
            return 'other'

    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()

    result = []
    previous_chr = content[0]
    previous_chr_type = char_type(previous_chr)

    i = 0
    while i < len(content):
        if content[i:i+3] == '不NG':
            i += 3
            continue
        if content[i:i+7] == '一句话告别NG':
            i += 7
            continue
        if content[i:i+4] == '实景对话':
            i += 4
            continue
        if content[i:i+8] == 'OOPS! NG':
            i += 8
            continue
        if content[i:i+3] == '场景！':
            i += 3
            continue

        chr = content[i]
        chr_type = char_type(chr)

        # Add newline between English and Chinese, except for numbers and punctuation
        if chr_type != previous_chr_type:
            if not (previous_chr.isdigit() or chr in '.,!?'):
                if not (chr.isdigit() or chr in '.,!?'):
                    result.append('\n') 

        result.append(chr)
        previous_chr_type = chr_type
        previous_chr = chr
        i += 1

    with open(output_path, 'w', encoding='utf-8') as file:
        file.write(''.join(result))

input_path = '/Users/Chen/Coding/myscript/en.txt'
output_path = '/Users/Chen/Coding/myscript/output.txt'
process_text(input_path, output_path)