#!/bin/bash

outputText=$(echo "$1" | sed  "s/^/\*/g")
if [[ $? == 0 ]];then
    osascript -e "set the clipboard to  {text:(\"$outputText\" as string), Unicode text:\"$outputText\"}"
    if [[ $? == 0 ]];then
        echo "$outputText"
        echo "successfully set the clipboard"
        exit 0
    fi
fi
echo "failed to set the clipboard"
exit 1
