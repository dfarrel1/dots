#!/usr/bin/env bash
# ------------------------------------------------------------------
# Self-Documentation Generator
# Extracts aliases and functions from profile/*.sh files, reads
# @desc / @usage annotations from source comments, and generates
# markdown tables. No Python dependency.
#
# Usage: ./doc_maker/generate.sh
# Or:    make docs
# ------------------------------------------------------------------

set -e

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
DOTDIR="${BASEDIR}/../profile"
DOCSDIR="${BASEDIR}/../docs"

mkdir -p "$DOCSDIR"

TOTAL_ITEMS=0
DOCUMENTED_ITEMS=0
ALLTABLES="${DOCSDIR}/ALLTABLES.md"
> "$ALLTABLES"

echo "# Dotfiles Reference" >> "$ALLTABLES"
echo "" >> "$ALLTABLES"
echo "_Auto-generated from source annotations. Run \`make docs\` to regenerate._" >> "$ALLTABLES"
echo "" >> "$ALLTABLES"

# ---------------------------------------------------------------
# extract_aliases <file>
#   Prints: name|desc
#   desc is the alias value (truncated) or @desc if present
# ---------------------------------------------------------------
extract_aliases() {
    local file="$1"
    while IFS= read -r line; do
        # Match: alias name='...' or alias name="..."
        local aname=$(echo "$line" | sed -E 's/^alias[[:space:]]+([^=]+)=.*/\1/')
        local aval=$(echo "$line" | sed -E "s/^alias[[:space:]]+[^=]+=//")
        # Truncate value for display
        local short_val=$(echo "$aval" | head -c 50)
        [ ${#aval} -gt 50 ] && short_val="${short_val}..."

        # Check for inline @desc
        local desc=""
        if echo "$line" | grep -q '# @desc'; then
            desc=$(echo "$line" | sed -E 's/.*# @desc[[:space:]]*//')
        else
            desc="\`${short_val}\`"
        fi

        echo "${aname}|${desc}"
    done < <(grep "^alias " "$file" 2>/dev/null)
}

# ---------------------------------------------------------------
# extract_functions <file>
#   Prints: name|desc|usage
#   Reads @desc and @usage from comment block above function def
# ---------------------------------------------------------------
extract_functions() {
    local file="$1"
    local prev_desc=""
    local prev_usage=""
    local in_comment_block=false

    while IFS= read -r line; do
        # Accumulate @desc and @usage from comment lines
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@desc[[:space:]]+(.*) ]]; then
            prev_desc="${BASH_REMATCH[1]}"
            in_comment_block=true
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*@usage[[:space:]]+(.*) ]]; then
            prev_usage="${BASH_REMATCH[1]}"
            in_comment_block=true
            continue
        fi

        # Non-annotation comment or blank line in a block — keep accumulating
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi

        # Check for function definition
        local fname=""
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_.-]*)[[:space:]]*\(\) ]]; then
            fname="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^function[[:space:]]+([a-zA-Z_][a-zA-Z0-9_.-]*) ]]; then
            fname="${BASH_REMATCH[1]}"
        fi

        if [ -n "$fname" ] && [ "$fname" != "help" ]; then
            # Skip internal/private functions starting with _
            if [[ "$fname" != _* ]]; then
                local desc="${prev_desc:-—}"
                local usage="${prev_usage}"
                echo "${fname}|${desc}|${usage}"
            fi
        fi

        # Reset annotation state on any non-comment line
        prev_desc=""
        prev_usage=""
        in_comment_block=false
    done < "$file"
}

# ---------------------------------------------------------------
# generate_md <file>
#   Produces a markdown table for one .sh file
# ---------------------------------------------------------------
generate_md() {
    local file="$1"
    local basename_sh=$(basename "$file")
    local basename_noext="${basename_sh%.*}"
    local outfile="${DOCSDIR}/${basename_noext}.auto.md"
    local has_content=false

    local aliases_data=$(extract_aliases "$file")
    local functions_data=$(extract_functions "$file")

    if [ -z "$aliases_data" ] && [ -z "$functions_data" ]; then
        # Empty file — write minimal stub
        echo "| Name | Type | Description |" > "$outfile"
        echo "|------|------|-------------|" >> "$outfile"
        return
    fi

    {
        echo "| Name | Type | Description |"
        echo "|------|------|-------------|"

        # Aliases
        if [ -n "$aliases_data" ]; then
            while IFS='|' read -r name desc; do
                [ -z "$name" ] && continue
                TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
                if [ "$desc" != "—" ]; then
                    DOCUMENTED_ITEMS=$((DOCUMENTED_ITEMS + 1))
                fi
                echo "| \`${name}\` | alias | ${desc} |"
            done <<< "$aliases_data"
        fi

        # Functions
        if [ -n "$functions_data" ]; then
            while IFS='|' read -r name desc usage; do
                [ -z "$name" ] && continue
                TOTAL_ITEMS=$((TOTAL_ITEMS + 1))
                if [ "$desc" != "—" ]; then
                    DOCUMENTED_ITEMS=$((DOCUMENTED_ITEMS + 1))
                fi
                local display_desc="$desc"
                [ -n "$usage" ] && display_desc="${desc} — \`${usage}\`"
                echo "| \`${name}\` | function | ${display_desc} |"
            done <<< "$functions_data"
        fi
    } > "$outfile"
}

# ---------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------
DOTFILES=($(ls "${DOTDIR}"/*.sh 2>/dev/null | xargs -n 1 basename))

for f in "${DOTFILES[@]}"; do
    filepath="${DOTDIR}/${f}"
    basename_noext="${f%.*}"

    echo "  Processing ${f}..."
    generate_md "$filepath"

    # Append to combined ALLTABLES.md
    echo "## ${basename_noext}" >> "$ALLTABLES"
    echo "" >> "$ALLTABLES"
    cat "${DOCSDIR}/${basename_noext}.auto.md" >> "$ALLTABLES"
    echo "" >> "$ALLTABLES"
done

# ---------------------------------------------------------------
# Coverage Summary
# ---------------------------------------------------------------
if [ "$TOTAL_ITEMS" -gt 0 ]; then
    PCT=$((DOCUMENTED_ITEMS * 100 / TOTAL_ITEMS))
else
    PCT=0
fi

{
    echo "---"
    echo ""
    echo "## Coverage"
    echo ""
    echo "| Metric | Count |"
    echo "|--------|-------|"
    echo "| Total items | ${TOTAL_ITEMS} |"
    echo "| Documented | ${DOCUMENTED_ITEMS} |"
    echo "| Undocumented | $((TOTAL_ITEMS - DOCUMENTED_ITEMS)) |"
    echo "| Coverage | ${PCT}% |"
    echo ""
    echo "_Generated: $(date '+%Y-%m-%d %H:%M')_"
} >> "$ALLTABLES"

echo ""
echo "Docs generated: ${DOCUMENTED_ITEMS}/${TOTAL_ITEMS} items documented (${PCT}%)"
echo "Output: ${ALLTABLES}"
