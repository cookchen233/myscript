#!/usr/bin/osascript
# Connect to th office VPN
#✅🟢✔️✔︎✓☑️ ❗️‼️
set status to ""
repeat (3)
    do shell script "networksetup -disconnectpppoeservice 'Atlantic'"
    do shell script "sudo macosvpn create --l2tp 'Atlantic' --endpoint $(curl -s https://bbs.safedao.net/office_ip.txt) --username vpn01 --password bbys13510211086 --sharedsecret 123456 --force --split"
    delay 0.2
    do shell script "networksetup -connectpppoeservice 'Atlantic'"
    set show_statu_times to 0
    repeat until status="connected"
        set status to do shell script "networksetup -showpppoestatus 'Atlantic'"
        set show_statu_times to show_statu_times+1
        if show_statu_times >= 10
            exit repeat
        end if
        delay 1
    end repeat
    If status="connected" then
        display notification  "Connection success" & " ✅" with title "VPN" sound name "Frog"
        return
        exit repeat
    end if
end repeat
display notification  "Connection failed" & " ❗️" with title "VPN" sound name "Frog"
