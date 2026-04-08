#!/bin/bash
# ------------------------------------------------------------------
# [MANUAL] Install tools that live outside Homebrew
#
# These are tools installed via npm, cargo, or standalone installers
# that were found active on this machine but aren't in the Brewfile.
# This script is NOT run by newcomp.sh — run it by hand.
#
# Usage: ./install-tools-manual.sh          (prints the list)
#        ./install-tools-manual.sh install   (installs everything)
# ------------------------------------------------------------------

set -e

install_npm_tools() {
    echo "── npm global packages ──"
    local tools=(pnpm yarn http-server)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo "   ✅ $tool: already installed"
        else
            echo "   -> Installing $tool..."
            npm install -g "$tool"
        fi
    done
}

install_cargo_tools() {
    echo "── cargo packages ──"
    if ! command -v cargo &>/dev/null; then
        echo "   ⚠️  cargo not found — install Rust first"
        return
    fi
    local tools=(just cargo-sbom cargo-udeps cargo-vendor-filterer cross tarts)
    for tool in "${tools[@]}"; do
        if cargo install --list 2>/dev/null | grep -q "^$tool "; then
            echo "   ✅ $tool: already installed"
        else
            echo "   -> Installing $tool..."
            cargo install "$tool"
        fi
    done
}

install_standalone() {
    echo "── standalone tools ──"

    # NetBird
    if command -v netbird &>/dev/null; then
        echo "   ✅ netbird: already installed"
    else
        echo "   -> NetBird: https://netbird.io/docs/how-to/installation"
        echo "      curl -fsSL https://pkgs.netbird.io/install.sh | sh"
    fi

    # ZeroTier
    if command -v zerotier-cli &>/dev/null; then
        echo "   ✅ zerotier: already installed"
    else
        echo "   -> ZeroTier: https://www.zerotier.com/download/"
        echo "      curl -s https://install.zerotier.com | sudo bash"
    fi
}

if [[ "${1:-}" == "install" ]]; then
    install_npm_tools
    echo ""
    install_cargo_tools
    echo ""
    install_standalone
    echo ""
    echo "Done."
else
    echo "Non-Homebrew tools to install:"
    echo "=============================="
    echo ""
    echo "npm global:   pnpm, yarn, http-server"
    echo "cargo:        just, cargo-sbom, cargo-udeps, cargo-vendor-filterer, cross, tarts"
    echo "standalone:   netbird, zerotier"
    echo ""
    echo "Run '$0 install' to install them all."
fi
