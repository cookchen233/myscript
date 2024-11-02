curl 'https://kf.ldtse.com/api/prize.Prize/getRangeOrderAmount' -G --data-urlencode 'start_time=2024-10-27 20:50:00' --data-urlencode 'end_time=2024-11-01 23:12:00' --data-urlencode 'unionid=o8vMF6l7hhpndkWW6BEWRXopztzo' --data-urlencode 'sign=83f61f062d15a81649838143a04236e9'

curl 'https://kf.ldtse.com/api/prize.Prize/getRights' -G --data-urlencode 'rightsId=1181437860957'

curl 'https://lc.jk.com/api/im.friend/send' -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: lCGcGn6tYoFAmGYh4zJrBrA0FK3RYKsUgy4rH459R/8=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"sendee_member_id":134,"type":"text","content":{"text":"遥爱你的2222"}}'

curl 'https://lc.jk.com/api/im.group/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'api-token: 1j/2uNmHnvzqsZGc5ffNb47yv+jV9K9uAcLPhdWuUvE=' \
    -H 'content-type: application/json' \
    -H 'origin: http://im.190.weixiushi.cn' \
    -H 'priority: u=1, i' \
    -H 'referer: http://im.190.weixiushi.cn/' \
    -H 'sec-ch-ua: "Microsoft Edge";v="129", "Not=A?Brand";v="8", "Chromium";v="129"' \
    -H 'sec-ch-ua-mobile: ?1' \
    -H 'sec-ch-ua-platform: "Android"' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 Edg/129.0.0.0' \
    --data-raw '{"group_id":"1","group_no":"25465722","type":"text","content":{"text":"09912"}}'

curl 'http://localhost:5173/admin/lottery.LotteryActivity/update' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'Connection: keep-alive' \
    -H 'Content-Type: application/json' \
    -H 'Cookie: Hm_lvt_e8002ef3d9e0d8274b5b74cc4a027d08=1728100233' \
    -H 'Origin: http://localhost:5173' \
    -H 'Referer: http://localhost:5173/lottery/activity/edit?id=10' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0' \
    -H 'admin-token: NNlnGoE1LFuDTRCqYgXuLIDnHdewbaSbIm8pCUyc0EM=' \
    -H 'sec-ch-ua: "Microsoft Edge";v="129", "Not=A?Brand";v="8", "Chromium";v="129"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'site-id: 14' \
    --data-raw '{"name":"yyy","desc":"jjjj","start_time":"2024-10-16 16:00:00","end_time":"2024-10-24 16:00:00","payment_amount_start_time":"2024-10-17 16:00:00","payment_amount_end_time":"0000-00-00 00:00:00","payment_amount_per_draw":"0.01","prizes":[{"name":"11","image_url":"https://api.13012345822.com/storage/upload/14/20241012/1728720112e7af477e799e48743653700f198abe9a.","quantity":1,"probability":0,"level_name":"1","level":1},{"name":"1","image_url":"https://api.13012345822.com/storage/upload/14/20241012/1728720112e7af477e799e48743653700f198abe9a.","quantity":1,"probability":0,"level_name":"1","level":2}],"is_enabled":0,"id":10,"site_id":14,"create_time":"2024-10-06 10:14:32","update_time":"2024-10-06 10:14:32"}'

curl 'https://lc.jk.com/api/lottery.LotteryActivity/drawLottery' \
    -H 'Accept: */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'Connection: keep-alive' \
    -H 'Origin: http://localhost:1024' \
    -H 'Referer: http://localhost:1024/' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1 Edg/129.0.0.0' \
    -H 'api-token: 5Wnn2J8ILQb6+QYuwtfbg2z2yptIEiBg2H0ymfvcrd4=' \
    -H 'channel: h5' \
    -H 'content-type: application/json' \
    -H 'site-id: 14' \
    --data-raw '{"activity_id":11}'

curl 'https://lc.jk.com/api/lottery.LotteryActivity/drawLottery' \
    -H 'Accept: */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'Connection: keep-alive' \
    -H 'Origin: http://localhost:1024' \
    -H 'Referer: http://localhost:1024/' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'User-Agent: Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 Edg/129.0.0.0' \
    -H 'api-token: 5Wnn2J8ILQb6+QYuwtfbg2z2yptIEiBg2H0ymfvcrd4=' \
    -H 'channel: h5' \
    -H 'content-type: application/json' \
    -H 'sec-ch-ua: "Microsoft Edge";v="129", "Not=A?Brand";v="8", "Chromium";v="129"' \
    -H 'sec-ch-ua-mobile: ?1' \
    -H 'sec-ch-ua-platform: "Android"' \
    -H 'site-id: 14' \
    --data-raw '{"activity_id":11}'

curl 'https://lc.jk.com/api/pay.Alipay/returnCallback' \
    -H 'Accept: */*' \
    -H 'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'Connection: keep-alive' \
    -H 'Origin: http://localhost:1024' \
    -H 'Referer: http://localhost:1024/' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1 Edg/129.0.0.0' \
    -H 'api-token: 5Wnn2J8ILQb6+QYuwtfbg2z2yptIEiBg2H0ymfvcrd4=' \
    -H 'channel: h5' \
    -H 'content-type: application/json' \
    -H 'site-id: 14' \
    --data-raw '{"order_id":11,"success_url":"xx"}'

curl 'https://lc.jk.com/api/im.Conversation/latestList' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WroVeOPQoz9xDEZUrOkvZMhW+YbsOROUUE9swA+Ofns=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"page":1,"limit":10,"keyword":""}' | jq .

curl "https://lc.jk.com/api/pay.Alipay/web?success_url=123&order_id=17"

curl 'https://api.13012345822.com/api/im.friend/getMsgList?friend_member_id=134' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WroVeOPQoz9xDEZUrOkvZMhW+YbsOROUUE9swA+Ofns=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"page":1,"limit":10,"keyword":"","type":"user","id":"3","friend_id":"134"}' | jq .

curl 'https://api.13012345822.com/api/im.group/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WroVeOPQoz9xDEZUrOkvZMhW+YbsOROUUE9swA+Ofns=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"group_id":"1","group_no":"25465722","type":"red_packet_room","content":{"amount":20,"sendee_group_id":"25465722"}}'

curl 'https://lc.jk.com/admin/lottery.LotteryActivity/lists?keywords=&page=1&page_size=20&search=&sort_field=create_time&sort_order=desc' \
    -H 'accept: application/json, text/plain, */*' \
    -H 'accept-language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6' \
    -H 'admin-token: S3pgfaOANvMPeT5Ch1E5xTjY34sXM4n7McudGyASvbA=' \
    -H 'origin: https://api.admin.13012345822.com' \
    -H 'priority: u=1, i' \
    -H 'referer: https://api.admin.13012345822.com/' \
    -H 'sec-ch-ua: "Microsoft Edge";v="129", "Not=A?Brand";v="8", "Chromium";v="129"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: same-site' \
    -H 'site-id: 14' \
    -H 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36 Edg/129.0.0.0'

curl 'https://lc.jk.com/api/lottery.LotteryActivity/drawLottery' \
    -H 'Connection: keep-alive' \
    -H 'api-token: ZiTpqHqSt6enkcHMCWxGWiYKazAELULK5tDuClFJjb4=' \
    -H 'channel: wechat' \
    -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1 wechatdevtools/1.06.2405020 MicroMessenger/8.0.5 Language/zh_CN webview/1729134545199618 webdebugger port/14107 token/1cdb8d82024dbf825f4af83d69cc384a' \
    -H 'site-id: 14' \
    -H 'content-type: application/json' \
    -H 'Accept: */*' \
    -H 'Origin: http://localhost:1024' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Referer: http://localhost:1024/ldt11/?token=ZiTpqHqSt6enkcHMCWxGWiYKazAELULK5tDuClFJjb4=' \
    -H 'Accept-Language: zh-CN,zh;q=0.9' \
    --data-binary '{"activity_id":11}' \
    --compressed

curl 'https://lc.jk.com/api/lottery.LotteryActivity/getInfo' \
    -H 'Connection: keep-alive' \
    -H 'api-token: 46HTA5tLaZtShl+m5hTaIsexEB1kC5yz4WWDExlczZU=' \
    -H 'channel: wechat' \
    -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1 wechatdevtools/1.06.2405020 MicroMessenger/8.0.5 Language/zh_CN webview/17291504048967530 webdebugger port/64060 token/3ceb2aefd2942b8ec6ff166cb4dd1381' \
    -H 'site-id: 14' \
    -H 'content-type: application/json' \
    -H 'Accept: */*' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Sec-Fetch-Mode: cors' \
    -H 'Sec-Fetch-Dest: empty' \
    -H 'Referer: http://localhost:1024/ldt11/?token=46HTA5tLaZtShl%2Bm5hTaIsexEB1kC5yz4WWDExlczZU%3D' \
    -H 'Accept-Language: zh-CN,zh;q=0.9' \
    -H 'Cookie: think_lang=zh-cn; PHPSESSID=e68c765f70dc35db08bbf2159571db3b' \
    --compressed

curl 'https://lc.jk.com/api/im.GroupAdmin/collectWorkpoints' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WroVeOPQoz9xDEZUrOkvZMhW+YbsOROUUE9swA+Ofns=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"group_id":"1","workpoint_type":"red_packet_room"}'

curl 'https://lc.jk.com/api/im.friend/myFriend' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: ykX97gnZgKmBkIbPPxeBTrq14FJuMoLgnih+lMSHUO8=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"page":1,"limit":10,"keyword":"","type":"addGroupUser","id":"1","group_no":"25465722","group_id":"1"}' | jq .

curl 'https://api.13012345822.com/api/im.group/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: Qo5juQyRsPhLS3HhwkRC29+p/MAXce9xmQUS6PDw2ZI=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"group_id":"1","group_no":"25465722","type":"text","content":{"text":"这样，用户即使继续输入，输入框显示的内容也不会超过6个字符"}}'

curl 'https://lc.jk.com/api/im.group/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: LmSbwZ6FinPQ01a8yj2o3Cg/4CHnL0zXzG+revNKL7E=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"group_id":"1","group_no":"25465722","type":"text","content":{"text":"测试数据2222"}}'

curl 'https://lc.jk.com/api/im.friend/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: ICFm/Tf3nOHi4MSBqgOmVv8YesAKzitejka31Lvj0DY=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"sendee_member_id":134,"type":"text","content":{"text":"测试99999测试99999"}}'

curl 'https://lc.jk.com/api/im.group/getMsgList?group_id=1' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WMSy62Ja27jXtl8se6u1T/ZUGZAxYlFR1rzJ2Qlqpfw=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"page":1,"limit":10,"keyword":"","type":"group","id":"1","group_no":"25465722","cachid":"9"}'

curl 'https://lc.jk.com/api/im.Conversation/latestList' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: WMSy62Ja27jXtl8se6u1T/ZUGZAxYlFR1rzJ2Qlqpfw=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"page":1,"limit":10,"keyword":""}'

curl 'https://api.13012345822.com/api/im.group/send' \
    -H 'accept: */*' \
    -H 'accept-language: zh-CN,zh;q=0.9' \
    -H 'api-token: UlEyS/5Fmi4EC1quJSSAlCOYgvVLlPArYz0BR6ppoyo=' \
    -H 'content-type: application/json' \
    -H 'origin: http://localhost:5173' \
    -H 'priority: u=1, i' \
    -H 'referer: http://localhost:5173/' \
    -H 'sec-fetch-dest: empty' \
    -H 'sec-fetch-mode: cors' \
    -H 'sec-fetch-site: cross-site' \
    -H 'site-id: 13' \
    -H 'user-agent: Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1' \
    --data-raw '{"group_id":"1","group_no":"25465722","type":"text","content":{"text":"38275832423423"}}'

curl 'https://api.ldtse.com/api/oa.config/myModel' \
    -H 'channel: weapp' \
    -H 'content-type: application/json' \
    -H 'Referer: https://servicewechat.com/wxe17ffddcbe316019/0/page-frame.html' \
    -H 'site-id: 8' \
    -H 'User-Agent: Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.53(0x1800352c) NetType/WIFI Language/zh_CN' \
    -H 'api-token: ' \
    --compressed
