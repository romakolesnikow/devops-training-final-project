#!/bin/sh

/opt/bingo/bingo prepare_db 

/opt/bingo/bingo run_server &
while true; do
    response=$(wget --server-response http://localhost:30238/ping 2>&1 | awk '/^  HTTP/{print $2}')
    pid="$(pgrep bingo)"
    if [[ $response == "500" ]]; then
        killall -15 $(pid)
        /opt/bingo/bingo run_server &
    else
        break
    fi
    sleep 5
done