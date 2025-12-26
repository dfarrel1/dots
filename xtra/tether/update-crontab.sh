#!/bin/bash

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CONNECT_SCRIPT="${CURRENT_DIR}/connect-to-hotspot.sh"
cron_entry="* * * * * ${USER} ${CONNECT_SCRIPT}"

current_crontab=$(crontab -l 2>/dev/null || true)
if [ -s "$current_crontab" ]; then
    echo "$current_crontab" > /tmp/crontab.tmp
    echo "$cron_entry" >> /tmp/crontab.tmp
    crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
else
    echo "$cron_entry" | crontab -
fi