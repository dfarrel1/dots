#!/bin/bash
# ------------------------------------------------------------------
# [AUDIT] REPO SECURITY SCANNER
# 
# FEATURES:
# 1. SELF-AWARE: Obfuscated patterns to prevent flagging itself.
# 2. GIT-NATIVE: Uses 'git grep' to respect .gitignore.
# 3. CONSISTENT EXCLUSIONS: Applies ignores to BOTH files and history.
# ------------------------------------------------------------------

set -e

# --- CONFIGURATION ---

SCRIPT_NAME=$(basename "$0")
CONFIG_FILE="$(dirname "$0")/../private/audit_config.txt"

# 1. Define Secret Patterns (Obfuscated)
H1="-----BEGIN"
H2=" .* PRIVATE KEY-----"
KEY_HEADERS="${H1}${H2}"

P1="ssh-(rsa|ed25519|dss)"
P2=" AAAA"
PUB_KEYS="${P1}${P2}"

C1="op://"
C2="ghp_"
C3="AKIA"
CLOUD_KEYS="(${C1}[a-zA-Z0-9]+|${C2}[a-zA-Z0-9]+|${C3}[0-9A-Z]{16})"

SECRET_REGEX="($KEY_HEADERS|$PUB_KEYS|$CLOUD_KEYS)"

# 2. Dynamic Identity Loading
GIT_NAME=$(git config user.name || echo "")
GIT_EMAIL=$(git config user.email || echo "")

if GH_USER=$(gh api user -q .login 2>/dev/null); then
    :
else
    GH_USER=""
fi

# 3. Load Forbidden Strings
SEARCH_TERMS=()
[ -n "$GIT_NAME" ] && SEARCH_TERMS+=("$GIT_NAME")
[ -n "$GIT_EMAIL" ] && SEARCH_TERMS+=("$GIT_EMAIL")
[ -n "$GH_USER" ] && SEARCH_TERMS+=("$GH_USER")

if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] || [ -z "$line" ] && continue
        SEARCH_TERMS+=("$line")
    done < "$CONFIG_FILE"
fi

# 4. ALLOW PATTERNS (False Positive Filter)
ALLOW_REGEX="(github\.com/$GH_USER|src/github\.com/$GH_USER|op://.*<.*>)"

# 5. NOISY FILE PATHSPECS
# These match the syntax for git grep AND git log pathspecs
IGNORE_SPECS=(
    ":!*.lock"
    ":!*.json"
    ":!*.png"
    ":!*.jpg"
    ":!node_modules"
    ":!$SCRIPT_NAME"
    ":!xtra/utils/auditrepo.sh"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Starting Security Audit...${NC}"
echo "----------------------------------------------------------------"
echo "🔍 Scanning identities:"
echo "   - Git Name:  ${GIT_NAME}"
echo "   - Git Email: ${GIT_EMAIL}"
echo "----------------------------------------------------------------"

# --- PART 1: SCAN TRACKED FILES ---
echo -e "${YELLOW}📂 Phase 1: Scanning Tracked Files${NC}"

FOUND_CURRENT=0

# A. Scan for Terms (PII)
for str in "${SEARCH_TERMS[@]}"; do
    MATCHES=$(git grep -Iin "$str" -- . "${IGNORE_SPECS[@]}" 2>/dev/null | grep -vE "$ALLOW_REGEX" || true)

    if [ -n "$MATCHES" ]; then
        echo -e "${RED}   [PII FOUND] String '$str' found:${NC}"
        echo "$MATCHES" | sed 's/^/      /'
        FOUND_CURRENT=1
    fi
done

# B. Scan for Secrets (Regex)
MATCHES=$(git grep -IinE "$SECRET_REGEX" -- . "${IGNORE_SPECS[@]}" 2>/dev/null | grep -vE "$ALLOW_REGEX" || true)

if [ -n "$MATCHES" ]; then
    echo -e "${RED}   [SECRET FOUND] Potential Key/Token found:${NC}"
    echo "$MATCHES" | sed 's/^/      /'
    FOUND_CURRENT=1
fi

if [ $FOUND_CURRENT -eq 0 ]; then
    echo -e "${GREEN}   ✅ Current tracked files clean.${NC}"
else
    echo -e "${RED}   ⚠️  Review findings above.${NC}"
fi

echo "----------------------------------------------------------------"

# --- PART 2: SCAN GIT HISTORY ---
echo -e "${YELLOW}🕰️  Phase 2: Scanning History (Commits)${NC}"

FOUND_HISTORY=0

# A. Scan for Terms in History
for str in "${SEARCH_TERMS[@]}"; do
    # Pass IGNORE_SPECS to git log to skip lockfiles in history too
    RESULT=$(git log -S"$str" --source --all --oneline -- . "${IGNORE_SPECS[@]}" | grep -vE "$ALLOW_REGEX" || true)
    
    if [ -n "$RESULT" ]; then
        echo -e "${RED}   [HISTORY HIT] '$str' found in commits:${NC}"
        echo "$RESULT" | sed 's/^/      /'
        echo ""
        FOUND_HISTORY=1
    fi
done

# B. Scan for Secrets in History
# Pass IGNORE_SPECS here as well
if git log --all -G "$SECRET_REGEX" --oneline -- . "${IGNORE_SPECS[@]}" > /dev/null; then
     HITS=$(git log --all -G "$SECRET_REGEX" --oneline -- . "${IGNORE_SPECS[@]}" | head -n 5)
     
     # Double check if HITS is actually empty (false positive on binary or weird grep)
     if [ -n "$HITS" ]; then
         echo -e "${RED}   [HISTORY HIT] Secret patterns found in history.${NC}"
         echo "   Recent hits:"
         echo "$HITS" | sed 's/^/      /'
         FOUND_HISTORY=1
     fi
fi

echo "----------------------------------------------------------------"
if [ $FOUND_HISTORY -eq 1 ] || [ $FOUND_CURRENT -eq 1 ]; then
    echo -e "${RED}🚩 AUDIT FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 AUDIT PASSED${NC}"
    exit 0
fi