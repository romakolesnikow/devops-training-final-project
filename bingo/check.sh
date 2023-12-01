#!/bin/sh

while true; do
        status_code=$(wget --server-response -O /dev/null http://localhost:30238/ping 2>&1 | awk '/^  HTTP/{print $2}')
        if [ -n "$status_code" ] && [ "$status_code" -eq "500" ]; then
                docker restart bingo
        fi
        sleep 2
done