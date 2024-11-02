#!/bin/bash
# lftp bbys-ftp:ftp888@192.168.199.61:8821 <<EOF
    # glob -a rm -rf pub-files/chenwenhao_ftp/bbys/*
    # quit
# EOF
while [[ 1 ]]; do
#     expect <<EOF
# spawn lftp -u ftp-in -p 21 192.168.199.213
# expect {
#     -re "密码:" { send "GjYN39%T0e@tL7K$\r" }
# }
# send "glob -a rm -rf chenwenhao_ftp/bbys/*\r"
# send "quit\r"
# interact
# EOF
    lftp "ftp-in":"GjYN39%T0e@tL7K$"@192.168.199.213:21 <<EOF
    glob -a rm -rf chenwenhao_ftp/bbys/*
    quit
    EOF
    sleep 120
done