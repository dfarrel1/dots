#!/bin/bash
# ------------------------------------------------------------------
# [MANUAL] Install apps not available via Homebrew
#
# These are apps found in /Applications that were installed manually
# (direct download, App Store, vendor installer, etc.).
# This script is NOT run by newcomp.sh — run it by hand as a checklist.
#
# Usage: ./install-apps-manual.sh          (prints the list)
#        ./install-apps-manual.sh install   (opens download pages)
# ------------------------------------------------------------------

APPS=(
    "Cursor|https://cursor.sh"
    "Discord|https://discord.com/download"
    "Firefox|https://www.mozilla.org/firefox/new/"
    "NordVPN|https://nordvpn.com/download/mac/"
    "Surfshark|https://surfshark.com/download/macos"
    "Rocket.Chat|https://rocket.chat/install"
    "Zulip|https://zulip.com/apps/mac"
    "Mattermost|https://mattermost.com/apps/"
    "Webex|https://www.webex.com/downloads.html"
    "Zoom|https://zoom.us/download"
    "VMware Fusion|https://www.vmware.com/products/fusion.html"
    "Canva|https://www.canva.com/download/mac/"
    "Box|https://www.box.com/resources/downloads"
    "balenaEtcher|https://etcher.balena.io/"
    "Raspberry Pi Imager|https://www.raspberrypi.com/software/"
    "Inkscape|https://inkscape.org/release/"
    "OpenCPN|https://opencpn.org/OpenCPN/info/downloads.html"
    "NetBird|https://netbird.io/docs/how-to/installation"
    "ZeroTier|https://www.zerotier.com/download/"
    "NFC Tools|https://www.wakdev.com/en/apps/nfc-tools-pc-mac.html"
    "AppGate SDP|https://www.appgate.com/support/software-defined-perimeter-support"
)

if [[ "${1:-}" == "install" ]]; then
    echo "Opening download pages in your browser..."
    for entry in "${APPS[@]}"; do
        name="${entry%%|*}"
        url="${entry##*|}"
        echo "   -> $name: $url"
        open "$url"
        sleep 1
    done
else
    echo "Apps installed manually (not via Homebrew):"
    echo "============================================"
    for entry in "${APPS[@]}"; do
        name="${entry%%|*}"
        url="${entry##*|}"
        printf "  %-25s %s\n" "$name" "$url"
    done
    echo ""
    echo "Run '$0 install' to open all download pages in your browser."
fi
