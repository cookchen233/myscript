#!/bin/bash

while true; do
    ip=$(curl -s -H "Cache-Coiiiiintrol: no-cache, no-store" https://bbs.safedao.net/office_ip.txt)
    echo "ip: $ip"
    if [[ -n "$ip" ]]; then
        sed -i "" "s/full address.*/full address:s:$ip:4471/g" /Users/Chen/Coding/myscript/remote_office_4471.rdp
    fi
    sleep 60
done
