# 带ss的容器

# sudo apt update
# sudo apt install -y ufw

# 安装 Docker（Ubuntu/Debian）
# curl -fsSL https://get.docker.com | bash


FROM ghcr.io/mhsanaei/3x-ui:latest

USER root

RUN apk update && apk add iproute2 curl bash

# 保证启动脚本可用
CMD ["/app/x-ui"]

# docker build -t 3x-ui-with-ss .
# docker rm -f 3x-ui

# docker run -d  --name 3x-ui --restart unless-stopped -p 2053:2053 3x-ui-with-ss


# sudo apt install -y ufw
# sudo ufw allow 2053
