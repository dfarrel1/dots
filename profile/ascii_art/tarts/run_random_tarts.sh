#!/bin/bash

# --- 1. Dependencies Check ---
if ! command -v tarts &> /dev/null; then
    echo "tarts not found. Installing..."
    if command -v cargo &> /dev/null; then
        cargo install tarts
        export PATH="$HOME/.cargo/bin:$PATH"
    else
        echo "Error: Rust/Cargo is not installed."
        exit 1
    fi
fi

# --- 2. Configuration ---
# Removed 'matrix' from this list
SAVERS=("boids" "fire" "life" "plasma" "cube" "crab" "donut" "pipes")

# --- 3. Selection ---
# Reseed RANDOM using the Process ID ($$) to prevent repetition streaks
RANDOM=$$ 
# Pick a random index
SELECTED_SAVER=${SAVERS[$RANDOM % ${#SAVERS[@]}]}

# --- 4. Execution ---
echo "Starting: $SELECTED_SAVER"
# 'exec' replaces the current shell with the program.
# When tarts ends (via Ctrl+C), it's over immediately.
exec tarts "$SELECTED_SAVER"