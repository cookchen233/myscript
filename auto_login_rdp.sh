#!/bin/bash

open -a /Applications/Microsoft\ Remote\ Desktop\ Beta.app ~/Coding/myscript/remote_office_4471.rdp
osascript -e '
set windowTitle to ""
tell application "System Events"
    set windowSize to size of first window of (first application process whose frontmost is true)
    set width to item 1 of windowSize as number
    if width < 600
        delay 0.1
        tell application "System Events" to keystroke "#GBYjt" & return
    end
end tell
'