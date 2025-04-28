#!/bin/bash

im-select $(im-select | grep -q "com.apple.keylayout.ABC" && echo "com.sogou.inputmethod.sogou.pinyin" || echo "com.apple.keylayout.ABC")