#!/bin/bash
# ------------------------------------------------------------------
# [PUBLIC] NEW COMPUTER BOOTSTRAP (Cross-Platform & Idempotent)
#
# 1. Detects OS (Linux/Mac) and installs base tools (git, jq, op).
# 2. Authenticates to 1Password (Service Account or User).
# 3. Downloads & Runs the Private Restore Script (Identity/Plumbing).
# 4. Installs Apps (Brewfile on Mac, Aptfile on Linux).
# 5. Configures Dev Tools (Rust, Garage, Claude Code, AWS).
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TEMP_SCRIPT_PATH="$(mktemp "/tmp/restore_secrets_from_1p.XXXXXX.sh")"
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
    echo "   WARNING: Service tokens are highly sensitive. Only paste tokens from a trusted source"
    echo "            and be aware that they may be visible in process environment listings."
    read -s -p "   Service Token (Optional): " MANUAL_TOKEN
    echo ""

    if [ -n "$MANUAL_TOKEN" ]; then
        if [[ "$MANUAL_TOKEN" =~ ^op_service_account_ ]]; then
            export OP_SERVICE_ACCOUNT_TOKEN="$MANUAL_TOKEN"
            eval "$(op signin)"
        else
            echo "   ❌ Token format does not look like a 1Password service account token."
            echo "      Ignoring pasted value and attempting Desktop login instead..."
            unset MANUAL_TOKEN
            echo "   Attempting Desktop login..."
            eval "$(op signin)"
        fi
        unset MANUAL_TOKEN
    else
        echo "   No token provided. Attempting Desktop login..."
        eval "$(op signin)"
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
    # macOS: Brewfile
    if [[ -f "$STATE_DIR/brew_complete" ]]; then
        echo "   ✅ Brew packages: Skipped (Already done)."
    else
        BREWFILE="${SCRIPT_DIR}/Brewfile"
        if [[ -f "$BREWFILE" ]]; then
            echo "   -> Running Brewfile..."
            brew bundle install --file="$BREWFILE"
            touch "$STATE_DIR/brew_complete"
        else
            echo "   ⚠️  No Brewfile found at $BREWFILE"
        fi
    fi

elif [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux: Aptfile
    if [[ -f "$STATE_DIR/apt_complete" ]]; then
        echo "   ✅ Apt packages: Skipped (Already done)."
    else
        APTFILE="${SCRIPT_DIR}/Aptfile"
        if [[ -f "$APTFILE" ]]; then
            echo "   -> Reading Aptfile..."
            # Filter comments (#) and blank lines into an array
            readarray -t PACKAGES < <(grep -vE "^\s*#" "$APTFILE" | sed '/^\s*$/d')

            if ((${#PACKAGES[@]} > 0)); then
                echo "   -> Installing packages..."
                sudo apt-get update -qq
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"
                touch "$STATE_DIR/apt_complete"
            else
                echo "   ⚠️  Aptfile is empty."
            fi
        else
            echo "   ⚠️  No Aptfile found at $APTFILE. Installing minimal defaults..."
            sudo apt-get install -y zsh tmux htop ripgrep fd-find
            touch "$STATE_DIR/apt_complete"
        fi
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
            echo "   ⚠️  Could not find cargo after Rust installation."
        fi
    fi
fi

# Claude Code CLI
if [[ -f "$STATE_DIR/claude_complete" ]]; then
    echo "   ✅ Claude Code: Skipped."
else
    echo "   -> Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
    touch "$STATE_DIR/claude_complete"
fi

# Environment Config (Restored)
echo "🌍 Configuring Environment..."
SHELL_RC="$HOME/.bashrc"
[ "$OS_TYPE" == "Darwin" ] && SHELL_RC="$HOME/.zshrc"

if [ -f "$SHELL_RC" ]; then
    if ! grep -q "set -a.*\.env.*set +a" "$SHELL_RC"; then
        cat >> "$SHELL_RC" <<'EOF'
if [ -f .env ]; then
  set -a
  . .env
  set +a
fi
EOF
        echo "   -> Added .env loader to $SHELL_RC"
    else
        echo "   ✅ .env loader already present in $SHELL_RC"
    fi
fi

echo "----------------------------------------------------------------"
echo "🎉 BOOTSTRAP COMPLETE"
echo "----------------------------------------------------------------"