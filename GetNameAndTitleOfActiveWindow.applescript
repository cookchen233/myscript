#!/usr/bin/osascript

# taken from user Albert's answer on StackOverflow
# http://stackoverflow.com/questions/5292204/macosx-get-foremost-window-title
# tested on Mac OS X 10.7.5

global frontApp, frontAppName, windowTitle, x
set windowTitle to ""
tell application "System Events"
    set frontApp to first application process whose frontmost is true
    #set x to the {title, id} of active window
    set frontAppName to name of frontApp
    set x to attributes of frontApp
    set windowSize to size of first window of (first application process whose frontmost is true)
    set x to item 1 of windowSize as text
    tell process frontAppName
        tell (1st window whose value of attribute "AXMain" is true)
            set windowTitle to value of attribute "AXTitle"
        end tell
    end tell
end tell

tell application "System Events" to keystroke x