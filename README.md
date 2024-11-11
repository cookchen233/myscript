# My development toolkit

## auto-commit git仓库自动提交
适用于笔记类项目.
运行 ./auto-commit/main.py, 当文件发生变更时, 将自动提交并推送仓库. 
可在.env文件设置多个不同的仓库.

## notification-server 异常通知服务器
通常错误通知都集成在项目中, 为了使不同的项目能统一错误通知, 同时减轻维护负担, 故将错误通知单独抽离为一个网络服务, 使不同语言的项目都能共用.
该服务将根据.env配置文件播放声音(本地Mac),邮件通知以及discord频道通知.

## sy 合并+推送+同步远程文件的快捷命令, syp.sh极致性能优化, 减少推送耗时
