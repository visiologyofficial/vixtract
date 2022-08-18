#!/bin/bash

FILE=/opt/cronicle/logs/cronicled.pid
if [ -f "$FILE" ]; then
    rm /opt/cronicle/logs/cronicled.pid
fi

/opt/cronicle/bin/control.sh setup
/opt/cronicle/bin/control.sh start
tail -f /dev/null