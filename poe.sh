#!/bin/zsh

open -a 'Poe.app'

osascript <<ost
tell application "System Events" 

    -- 输入框焦点
    keystroke key code 53 using {shift down}

end tell
ost
