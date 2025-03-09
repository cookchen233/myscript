# 树莓派命令行消息与声音功能实现方案

## 概述
目标：通过树莓派实现跨国命令行通信。你寄给7岁儿子一个预配置的树莓派，他插上电源、显示器、键盘和音箱后，开机即可使用命令行收发消息。你能远程发送消息并触发声音，他能敲键盘回复（用英语）。

---

## 一、购买硬件

在淘宝、京东或 Amazon 购买以下硬件：

| 硬件                  | 规格/推荐                | 价格（人民币） |
|-----------------------|--------------------------|----------------|
| **树莓派**            | Raspberry Pi 4（4GB）    | 300-500        |
| **Micro HDMI转HDMI线**| 1-2米                   | 20-50          |
| **USB键盘**           | 任意简单USB键盘          | 50-100         |
| **Micro SD卡**        | 16GB或32GB              | 30-60          |
| **电源适配器**        | 5V 3A USB-C             | 50             |
| **3.5mm小音箱**       | 带3.5mm插头的迷你音箱    | 20-50          |

- **总成本**：约470-710人民币  
- **寄送**：用EMS或DHL，1-2公斤，约100-300人民币  
- **注意**：假设他有HDMI显示器（电视或电脑屏），若无，需加买（约300-500人民币）。

---

## 二、在寄出前配置树莓派

在你电脑和树莓派上完成以下步骤，确保他插上就能用。

### 1. 刷系统
- 下载 [Raspberry Pi OS Lite](https://www.raspberrypi.com/software/)（无桌面版）。  
- 用 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) 刷到SD卡：  
  1. 插SD卡到电脑。  
  2. 打开 Imager，选择“Raspberry Pi OS Lite”，选SD卡，点击“Write”。  
- 配置SSH：  
  - 刷完后，SD卡`boot`分区弹出，在里面新建空文件 `ssh`（无后缀）。

### 2. 配置开机进命令行
- 在`boot`分区：  
  - 编辑 `cmdline.txt`，末尾加空格和 `console=tty1`。  
  - 编辑 `config.txt`，末尾加一行 `disable_overscan=1`。

### 3. 设置Wi-Fi
- 在`boot`分区新建文件 `wpa_supplicant.conf`，填他家Wi-Fi信息：  
  ```bash
  country=US
  ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
  update_config=1
  network={
      ssid="他家WiFi名"
      psk="他家WiFi密码"
  }
  ```

### 4. 启动并安装软件
- 把SD卡插进树莓派，接Micro HDMI到显示器，插键盘，接电源启动。  
- 默认登录：用户 `pi`，密码 `raspberry`。  
- 修改密码（可选）：  
  ```bash
  passwd
  ```
  输入新密码（如 `mypison123`）。  
- 更新系统：  
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- 安装工具：  
  ```bash
  sudo apt install netcat alsa-utils -y
  ```

### 5. 配置声音
- 插上3.5mm音箱到树莓派音频口。  
- 测试声音：  
  ```bash
  aplay /usr/share/sounds/alsa/Front_Center.wav
  ```
  - 若无声，编辑 `/boot/config.txt`，加一行 `dtparam=audio=on`，保存后重启：  
    ```bash
    sudo reboot
    ```
  - 再试 `aplay`，听到“Front Center”说明OK。  
- 自定义声音（可选）：  
  - 用手机录“Hi, son!”，存为 `hi.wav`。  
  - 稍后通过SSH上传到 `/home/pi/`。

### 6. 设置消息+声音脚本
- 创建脚本：  
  ```bash
  nano /home/pi/chat.sh
  ```
- 输入以下内容：  
  ```bash
  #!/bin/bash
  echo "Hi son, type here to chat with dad!" > /tmp/chat.txt
  while true; do
      nc -l 12345 > /tmp/input.txt
      if grep -q "PLAYSOUND" /tmp/input.txt; then
          aplay /home/pi/hi.wav &
          echo "Dad sent a sound!" >> /tmp/chat.txt
      else
          cat /tmp/input.txt >> /tmp/chat.txt
      fi
  done
  ```
- 保存（Ctrl+O，回车，Ctrl+X退出）。  
- 加执行权限：  
  ```bash
  chmod +x /home/pi/chat.sh
  ```
- 上传自定义声音（若有）：  
  - 在你电脑：  
    ```bash
    scp hi.wav pi@树莓派IP:/home/pi/
    ```
    （IP用 `ifconfig` 查）。

### 7. 开机自动运行
- 编辑开机脚本：  
  ```bash
  sudo nano /etc/rc.local
  ```
- 在 `exit 0` 前加一行：  
  ```bash
  /home/pi/chat.sh &
  ```
- 保存退出。

### 8. 处理动态IP
- 翻墙访问 [noip.com](https://www.noip.com)，注册账号，建免费域名（如 `myson.ddns.net`）。  
- 在树莓派安装DDNS：  
  ```bash
  sudo apt install ddclient -y
  ```
- 配置DDNS：  
  ```bash
  sudo nano /etc/ddclient.conf
  ```
- 输入：  
  ```bash
  protocol=dyndns2
  use=web
  server=dynupdate.no-ip.com
  login=你的noip用户名
  password=你的noip密码
  myson.ddns.net
  ```
- 保存退出，启动：  
  ```bash
  sudo ddclient
  ```

### 9. 测试
- 重启树莓派：  
  ```bash
  sudo reboot
  ```
- 屏幕应显示：`Hi son, type here to chat with dad!`  
- 在你电脑（需Linux或Windows装WSL）：  
  - 发消息：  
    ```bash
    echo "Test message" | nc 树莓派IP 12345
    ```
    看屏幕是否追加 `Test message`。  
  - 发声音：  
    ```bash
    echo "PLAYSOUND" | nc 树莓派IP 12345
    ```
    听音箱响，屏幕加 `Dad sent a sound!`。

---

## 三、打包寄送
- **物品**：树莓派、SD卡（已配置）、Micro HDMI线、USB键盘、3.5mm音箱、电源适配器。  
- **说明纸条**（贴在包裹里）：  
  ```
  Dear Son,
  1. Plug the small box to power, TV (thin cable), keyboard, and little speaker.
  2. Wait a bit, you’ll see my words on screen. Sometimes you’ll hear me say hi!
  3. Type on the keyboard and press Enter to talk to dad.
  Love, Dad
  ```

---

## 四、你使用方法
在他收到并插上后：

1. **查他IP**  
   - 他开机后，域名 `myson.ddns.net` 会绑定树莓派IP。  
   - 你ping确认：  
     ```bash
     ping myson.ddns.net
     ```
2. **发送消息**  
   - 在你Linux电脑（或WSL）：  
     ```bash
     echo "Hey son, how’s your day?" | nc myson.ddns.net 12345
     ```
     他屏幕显示：`Hey son, how’s your day?`  
3. **播放声音**  
   - 输入：  
     ```bash
     echo "PLAYSOUND" | nc myson.ddns.net 12345
     ```
     他听到“Hi, son!”，屏幕加 `Dad sent a sound!`  
4. **接收回复**  
   - 开终端监听：  
     ```bash
     nc -l 12345
     ```
     他敲键盘（比如 `Good, dad!`）回车，你看到回复。

---

## 五、他使用方法
- **插上**  
  - 接Micro HDMI到显示器，插键盘，接3.5mm音箱，插电源。  
  - 30秒后屏幕显示：`Hi son, type here to chat with dad!`  
- **收到消息**  
  - 你的消息直接显示（比如 `Hey son, how’s your day?`）。  
  - 你发 `PLAYSOUND`，音箱响，屏幕加 `Dad sent a sound!`。  
- **回复**  
  - 他敲键盘（比如 `Good, dad!`），回车，发到你。

---

## 六、注意事项
- **Wi-Fi**：寄前确认他家Wi-Fi名和密码，填错连不上。  
- **端口**：他路由器需开12345端口（若不通，需他家人帮忙，或你用云服务器中转）。  
- **音箱**：确保寄3.5mm接口，别漏了。  
- **测试**：寄前在家试，确保开机正常。

---

## 七、总成本
- **硬件**：约470-710人民币  
- **寄送**：100-300人民币  
- **总计**：570-1010人民币

---