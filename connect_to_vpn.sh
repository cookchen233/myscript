#!/bin/bash
# Connect to th office VPN

is_vpn_connected(){
    for i in {1..20}; do
        status=$(networksetup -showpppoestatus Atlantic)
        echo  "$status $i"
        if [[ $status == "connected" ]]; then
            return 0
        elif [[ $status == "disconnected" ]]; then
            return 1
        else
            sleep 1
        fi
    done
    return 1
}

connect_to_vpn(){
    ssid=$(/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport -I  | awk -F' SSID: '  '/ SSID: / {print $2}')
    echo "$ssid"
    if [[ $ssid == "502_5G" || $ssid == "PC-20221031FVTA 7489" || $(networksetup -showpppoestatus Atlantic) == "connected" ]]; then
        if [[ $1 ]]; then
            exit 0
        fi
        return 0
    fi
    ip=$(curl -s -H "Cache-Control: no-cache, no-store" https://bbs.safedao.net/office_ip.txt)
    echo "$ip"
    for i in {1..2};do
        networksetup -disconnectpppoeservice Atlantic
        sudo macosvpn create --l2tp Atlantic --endpoint "$ip" --username vpn01 --password bbys13510211086 --sharedsecret bbys2023 --force --split
        sleep 0.3
        networksetup -connectpppoeservice Atlantic
        if is_vpn_connected;then
            return 0
        fi
    done
    return 1
    
}

if connect_to_vpn "$1";then
    osascript -e 'display notification "Connection success ✅" with title "VPN"'
    exit 0
else
    osascript -e 'display notification "Connection failed ❗️" with title "VPN"'
    exit 1
fi