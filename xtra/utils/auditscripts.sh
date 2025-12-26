#!/bin/bash
# ------------------------------------------------------------------
# [AUDIT] 1PASSWORD SCRIPT DIFF
# Checks if local scripts match the versions stored in 1Password.
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Load the shared config so we use the correct Vault/Item names
CONFIG_FILE="$SCRIPT_DIR/../bootstrap.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "⚠️  Config not found at $CONFIG_FILE. Using defaults."
fi

# Fallbacks if config is missing
REMOTE_RESTORE_TITLE="${OP_SCRIPT_TITLE:-sys_script_restore}"
REMOTE_PUSH_TITLE="sys_script_push" # Usually not in bootstrap.conf, so hardcoded default is fine

# Map Local Filenames to 1Password Item Titles
# Format: "LocalFileName:RemoteTitle"
TARGETS=(
    "restore_secrets_from_1p.sh:$REMOTE_RESTORE_TITLE"
    "push_secrets_to_1pass.sh:$REMOTE_PUSH_TITLE"
)

LOCAL_DIR="$SCRIPT_DIR/../private"
TEMP_DIR="/tmp/op_script_diff"

# --- 1. PREREQUISITES & AUTH ---

if ! command -v op &> /dev/null; then
    echo "❌ Error: 'op' CLI not found."
    exit 1
fi

echo "🔐 Authentication Check..."
if ! op account get >/dev/null 2>&1; then
    echo "   (Press ENTER to use Desktop/User login, or paste a Service Token)"
    read -s -p "   Service Token (Optional): " MANUAL_TOKEN
    echo "" 
    if [ -n "$MANUAL_TOKEN" ]; then
        export OP_SERVICE_ACCOUNT_TOKEN="$MANUAL_TOKEN"
    else
        eval $(op signin)
    fi
fi

# --- 2. DIFF LOGIC ---

echo "🔍 Checking Script Synchronization..."
mkdir -p "$TEMP_DIR"
ALL_SYNCED=true

for pair in "${TARGETS[@]}"; do
    # Split the string
    LOCAL_FILE="${pair%%:*}"
    REMOTE_TITLE="${pair##*:}"
    
    LOCAL_PATH="$LOCAL_DIR/$LOCAL_FILE"
    TEMP_PATH="$TEMP_DIR/$LOCAL_FILE"

    echo "----------------------------------------------------------------"
    echo "📄 Checking: $LOCAL_FILE"
    echo "   (Remote Title: $REMOTE_TITLE)"

    # 1. Check if local exists
    if [ ! -f "$LOCAL_PATH" ]; then
        echo "   ⚠️  LOCAL MISSING: $LOCAL_PATH does not exist."
        ALL_SYNCED=false
        continue
    fi

    # 2. Find Remote ID
    # We use tags from config if available to be precise
    CMD_ARGS=(item list --format=json)
    if [ -n "$OP_SCRIPT_TAG" ]; then CMD_ARGS+=(--tags "$OP_SCRIPT_TAG"); fi
    
    SCRIPT_ID=$(op "${CMD_ARGS[@]}" | jq -r ".[] | select(.title==\"$REMOTE_TITLE\") | .id" | head -n 1)

    if [ -z "$SCRIPT_ID" ]; then
        echo "   ❌ REMOTE MISSING: Could not find '$REMOTE_TITLE' in 1Password."
        ALL_SYNCED=false
        continue
    fi

    # 3. Download Remote
    if ! op document get "$SCRIPT_ID" --out-file "$TEMP_PATH" --force >/dev/null 2>&1; then
        echo "   ❌ DOWNLOAD FAILED: Could not fetch document."
        ALL_SYNCED=false
        continue
    fi

    # 4. Compare
    if cmp -s "$LOCAL_PATH" "$TEMP_PATH"; then
        echo "   ✅ SYNCED: Local matches Remote."
    else
        echo "   ⚠️  OUT OF SYNC: Differences detected."
        echo ""
        # Show colored diff
        diff -u --color=always "$TEMP_PATH" "$LOCAL_PATH" | sed 's/^/      /' || true
        echo ""
        echo "   👉 To update Remote: op document edit \"$REMOTE_TITLE\" \"$LOCAL_PATH\""
        ALL_SYNCED=false
    fi
done

# --- 3. CLEANUP ---
rm -rf "$TEMP_DIR"
echo "----------------------------------------------------------------"

if [ "$ALL_SYNCED" = true ]; then
    echo "🎉 All scripts are in sync."
else
    echo "⚠️  Some scripts are out of sync. Please update 1Password."
    exit 1
fi