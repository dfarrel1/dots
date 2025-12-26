#!/bin/bash

GOPATH=${GOPATH:-"~"}
TETHER_DIR=${GOPATH}/src/github.com/dfarrel1/dots/xtra/tether
SSID_ENV=${TETHER_DIR}/ssid.env
source ${SSID_ENV}
SSID=${HOTSPOT_SSID:-"DEFAULTSSID"}
PASSWORD=${HOTSPOT_PASSWORD:-"MissingPassword"}

# Check if already connected to the desired network
CURRENT_SSID=$(networksetup -getairportnetwork en0 | awk -F": " '{print $2}')

if [ "$CURRENT_SSID" != "$SSID" ]; then
  # Try to connect to the desired network
  networksetup -setairportnetwork en0 "$SSID" "$PASSWORD"
fi