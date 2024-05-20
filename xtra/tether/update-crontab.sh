#!/bin/bash

# TETHER_DIR="${GOPATH}/src/github.com/dfarrel1/dots/xtra/tether"
CURRENT_DIR=$(readlink -f $0)
CONNECT_SCRIPT="${CURRENT_DIR}/connect-to-hotspot.sh"
cron_entry="* * * * * ${CONNECT_SCRIPT}"

current_crontab=$(crontab -l 2>/dev/null)
echo "$current_crontab
$cron_entry" | crontab -