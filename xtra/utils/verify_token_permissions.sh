#!/bin/bash
# ------------------------------------------------------------------
# [TEST] VERIFY READ-ONLY TOKEN PERMISSIONS
# 
# Usage: ./xtra/utils/verify_token_permissions.sh
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Look for config one level up
CONFIG_FILE="$SCRIPT_DIR/../bootstrap.conf"

# --- 1. LOAD CONFIG ---
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Could not find config at '$CONFIG_FILE'"
    echo "   Please setup 'xtra/bootstrap.conf' first."
    exit 1
fi
source "$CONFIG_FILE"

# Fallback defaults if config is missing vars
# We use work-aws here because we know the token needs access to it
TEST_VAULT="${OP_VAULT_AWS:-work-aws}" 
TEST_ITEM="${OP_SCRIPT_TITLE:-sys_script_restore}"

echo "🛡️  TESTING LEAST PRIVILEGE..."
echo "   Target Vault: $TEST_VAULT"

# --- 2. AUTHENTICATION ---
if [ -z "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "   (Please paste your NEW 'Bootstrap Read-Only' token below)"
    read -s -p "   Token: " MANUAL_TOKEN
    echo ""
    if [ -n "$MANUAL_TOKEN" ]; then
        export OP_SERVICE_ACCOUNT_TOKEN="$MANUAL_TOKEN"
    else
        echo "❌ Error: No token provided."
        exit 1
    fi
fi

# --- 3. POSITIVE TEST (READ) ---
echo "1️⃣  Testing READ Permission (Should PASS)..."

# Try reading the vault itself (Simpler check than looking for a specific item that might be elsewhere)
if op vault get "$TEST_VAULT" >/dev/null 2>&1; then
     echo "   ✅ PASS: Token can read vault '$TEST_VAULT'."
else
     # If that fails, try listing items (another read check)
     if op item list --vault "$TEST_VAULT" --limit 1 >/dev/null 2>&1; then
         echo "   ✅ PASS: Token can list items in '$TEST_VAULT'."
     else
         echo "   ❌ FAIL: Token CANNOT read vault. Check permissions."
         exit 1
     fi
fi

# --- 4. NEGATIVE TEST (WRITE) ---
echo "2️⃣  Testing WRITE Permission (Should FAIL)..."
# We try to create a dummy item. We expect failure.
OUTPUT=$(op item create --category="Secure Note" --title="SECURITY_TEST_DUMMY" --vault "$TEST_VAULT" 2>&1 || true)

# Check for common "Access Denied" markers:
# - "Forbidden" (HTTP 403)
# - "101" (1Password Error Code for Permission Denied)
# - "permission" (Generic message)
if echo "$OUTPUT" | grep -E -q "Forbidden|101|permission"; then
    echo "   ✅ PASS: Write access DENIED (As expected)."
    echo "      (Server said: You do not have permission)"
elif echo "$OUTPUT" | grep -q "item created"; then
    echo "   ❌ FAIL: Token HAS Write access! This is not a Read-Only token."
    # Clean up the mess
    op item delete "SECURITY_TEST_DUMMY" --vault "$TEST_VAULT" >/dev/null 2>&1
    exit 1
else
    echo "   ⚠️  INCONCLUSIVE: Unexpected error message:"
    echo "$OUTPUT"
    exit 1
fi

echo "----------------------------------------------------------------"
echo "🎉 SUCCESS: Token is correctly scoped."
echo "----------------------------------------------------------------"