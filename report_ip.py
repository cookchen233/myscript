import requests,time

while True:
    print(time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(time.time())))
    print('reporting ip')
    r=requests.post('https://bbs.safedao.net/report_ip.php')
    print(r.text)
    time.sleep(60)