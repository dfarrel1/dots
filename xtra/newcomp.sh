#!/bin/bash
# ------------------------------------------------------------------
# [PUBLIC] NEW COMPUTER BOOTSTRAP (Cross-Platform & Idempotent)
# 
# 1. Detects OS (Linux/Mac) and installs base tools (git, jq, op).
# 2. Authenticates to 1Password (Service Account or User).
# 3. Downloads & Runs the Private Restore Script (Identity/Plumbing).
# 4. Installs Apps (Brewfile on Mac, Aptfile on Linux).
# 5. Configures Dev Tools (Rust, Garage, AWS).
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMP_SCRIPT_PATH="/tmp/restore_secrets_from_1p.sh"
STATE_DIR="$SCRIPT_DIR/.state"
mkdir -p "$STATE_DIR"

# Configuration (Defaults matching your 1Password setup)
OP_VAULT="work-dev"
RESTORE_SCRIPT_TITLE="sys_script_restore"

# --- 0. OS DETECTION ---
OS_TYPE=$(uname -s)
if [[ "$OS_TYPE" == "Darwin" ]]; then
    printf "🍎 macOS Detected.\n"
elif [[ "$OS_TYPE" == "Linux" ]]; then
    printf "🐧 Linux Detected.\n"
else
    printf "❌ Unsupported OS: $OS_TYPE\n"
    exit 1
fi

# --- 🛡️ SECURITY TRAP ---
cleanup() {
    EXIT_CODE=$?
    # Security: Wipe token from memory on exit
    unset OP_SERVICE_ACCOUNT_TOKEN
    rm -f "$TEMP_SCRIPT_PATH"
    if [ $EXIT_CODE -ne 0 ]; then
        echo "🧹 Cleanup complete (Exit Code: $EXIT_CODE)."
    fi
    exit $EXIT_CODE
}
trap cleanup EXIT INT TERM

# --- PHASE 1: BASE TOOLS ---
echo "----------------------------------------------------------------"
echo "🛠️  PHASE 1: BASE TOOLS"
echo "----------------------------------------------------------------"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS: Homebrew
    if ! command -v brew &> /dev/null; then
        echo "   -> Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    brew install 1password-cli jq git aws-vault

elif [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux: Apt
    echo "   -> Updating apt..."
    sudo apt-get update -qq
    sudo apt-get install -y curl git jq build-essential

    # Install 1Password CLI
    if ! command -v op &> /dev/null; then
        echo "   -> Installing 1Password CLI..."
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
        sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
        curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
        sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
        curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
        sudo apt-get update && sudo apt-get install -y 1password-cli
    fi
fi

# --- PHASE 2: AUTHENTICATION ---
echo "----------------------------------------------------------------"
echo "🔐 PHASE 2: AUTHENTICATION"
echo "----------------------------------------------------------------"

# Check if we are already logged in via Desktop/Env
if ! op account get >/dev/null 2>&1; then
    echo "   (Press ENTER to use Desktop/User login, or paste a Service Token)"
    read -s -p "   Service Token (Optional): " MANUAL_TOKEN
    echo "" 
    
    if [ -n "$MANUAL_TOKEN" ]; then
        export OP_SERVICE_ACCOUNT_TOKEN="$MANUAL_TOKEN"
    else
        echo "   No token provided. Attempting Desktop login..."
        eval $(op signin)
    fi
fi

# Final check
if ! op account get >/dev/null 2>&1; then
    echo "❌ Error: Could not authenticate to 1Password."
    exit 1
fi

# --- PHASE 3: SECURE RESTORE ---
echo "----------------------------------------------------------------"
echo "🧠 PHASE 3: IDENTITY & CONFIG RESTORE"
echo "----------------------------------------------------------------"

echo "   -> Fetching restore logic from Vault: $OP_VAULT"
# Note: This fetches the private script that handles SSH keys/Git Configs
op document get "$RESTORE_SCRIPT_TITLE" --vault "$OP_VAULT" --output "$TEMP_SCRIPT_PATH"

chmod +x "$TEMP_SCRIPT_PATH"
echo "   -> Executing Private Restore Script..."
echo "----------------------------------------------------------------"
"$TEMP_SCRIPT_PATH"
echo "----------------------------------------------------------------"

# --- PHASE 4: APPLICATIONS ---
echo "----------------------------------------------------------------"
echo "📦 PHASE 4: APPLICATIONS"
echo "----------------------------------------------------------------"

if [[ "$OS_TYPE" == "Darwin" ]]; then
    if [[ -f "$STATE_DIR/brew_complete" ]]; then
        echo "   ✅ Skipped (Already done)."
    else
        echo "   -> Running Brewfile..."
        brew bundle install --file="${SCRIPT_DIR}/Brewfile"
        touch "$STATE_DIR/brew_complete"
    fi

elif [[ "$OS_TYPE" == "Linux" ]]; then
    APTFILE="${SCRIPT_DIR}/Aptfile"
    
    if [[ -f "$STATE_DIR/apt_complete" ]]; then
        echo "   ✅ Skipped (Already done)."
    elif [[ -f "$APTFILE" ]]; then
        echo "   -> Reading Aptfile..."
        
        # Filter comments (#) and blank lines, convert to single line string
        PACKAGES=$(grep -vE "^\s*#" "$APTFILE" | tr '\n' ' ')
        
        if [[ -n "$PACKAGES" ]]; then
            echo "   -> Installing packages..."
            sudo apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES
            touch "$STATE_DIR/apt_complete"
        else
            echo "   ⚠️  Aptfile is empty."
        fi
    else
        echo "   ⚠️  No Aptfile found at $APTFILE. Installing minimal defaults..."
        sudo apt-get install -y zsh tmux htop ripgrep fd-find
    fi
fi

# --- PHASE 5: DEV TOOLS ---
echo "----------------------------------------------------------------"
echo "🦀 PHASE 5: DEV TOOLS"
echo "----------------------------------------------------------------"

# Rustup
if [[ -f "$STATE_DIR/rust_complete" ]]; then
    echo "   ✅ Rust: Skipped."
else
    echo "   -> Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    touch "$STATE_DIR/rust_complete"
fi

# Garage
if [[ -f "$STATE_DIR/garage_complete" ]]; then
    echo "   ✅ Garage: Skipped."
else
    echo "   -> Installing Garage..."
    if command -v cargo &> /dev/null; then
        cargo install garage
        touch "$STATE_DIR/garage_complete"
    else
        source "$HOME/.cargo/env" 2>/dev/null || true
        if command -v cargo &> /dev/null; then
            cargo install garage
            touch "$STATE_DIR/garage_complete"
        else
            echo "   ⚠️  Cargo not found. Skipping Garage."
        fi
    fi
fi

# Environment Config (Restored)
echo "🌍 Configuring Environment..."
SHELL_RC="$HOME/.bashrc"
[ "$OS_TYPE" == "Darwin" ] && SHELL_RC="$HOME/.zshrc"

if [ -f "$SHELL_RC" ]; then
    if ! grep -q "export \$(cat .env | xargs)" "$SHELL_RC"; then
        echo 'if [ -f .env ]; then export $(cat .env | xargs); fi' >> "$SHELL_RC"
        echo "   -> Added .env loader to $SHELL_RC"
    else
        echo "   ✅ .env loader already present in $SHELL_RC"
    fi
fi

echo "----------------------------------------------------------------"
echo "🎉 BOOTSTRAP COMPLETE"
echo "----------------------------------------------------------------"