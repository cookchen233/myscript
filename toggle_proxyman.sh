#!/bin/bash

# 配置变量
PROXYMAN_CLI="/Applications/Proxyman.app/Contents/MacOS/proxyman-cli"
NETWORK_SERVICE="Wi-Fi"  # 替换为你的网络接口名称，例如 "Ethernet"
CLASHX_PROXY_HOST="127.0.0.1"
CLASHX_PROXY_PORT="7890"  # 根据你的 ClashX 配置调整

# 检查 Proxyman 当前代理状态
CURRENT_PROXY=$(networksetup -getwebproxy "$NETWORK_SERVICE" | grep "Port: 9090")

if [ -n "$CURRENT_PROXY" ]; then
  # 如果 Proxyman 代理开启，则关闭它并启用 ClashX 代理
  echo "关闭 Proxyman 代理并启用 ClashX 代理..."
  "$PROXYMAN_CLI" proxy off
  sleep 1  # 等待代理切换
  networksetup -setwebproxy "$NETWORK_SERVICE" "$CLASHX_PROXY_HOST" "$CLASHX_PROXY_PORT"
  networksetup -setsecurewebproxy "$NETWORK_SERVICE" "$CLASHX_PROXY_HOST" "$CLASHX_PROXY_PORT"
  networksetup -setwebproxystate "$NETWORK_SERVICE" on
  networksetup -setsecurewebproxystate "$NETWORK_SERVICE" on
else
  # 如果 Proxyman 代理未开启，则开启它
  echo "开启 Proxyman 代理..."
  # 检查 Proxyman 是否运行，如果未运行则启动
  # if ! pgrep -f "Proxyman" > /dev/null; then
    open -a Proxyman
    sleep 2  # 等待 Proxyman 启动
  # fi
  "$PROXYMAN_CLI" proxy on
fi

echo "代理切换完成"