#!/bin/bash

PIDFILE="/tmp/shout_service.pid"
SERVICE_SCRIPT="/Users/Chen/Coding/myscript/shout_server_block.py"

start() {
    if [ -f $PIDFILE ]; then
        echo "Service already running"
        return
    fi
    nohup python3 $SERVICE_SCRIPT > /tmp/shout_service.log 2>&1 &
    echo $! > $PIDFILE
    echo "Service started"
}

stop() {
    if [ ! -f $PIDFILE ]; then
        echo "Service not running"
        return
    fi
    kill $(cat $PIDFILE)
    rm $PIDFILE
    echo "Service stopped"
}

restart() {
    stop
    sleep 2
    start
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac