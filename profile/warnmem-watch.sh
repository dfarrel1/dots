#!/usr/bin/env bash
# warnmem-watch — background macOS memory-pressure notifier (companion to the
# `warnmem` shell function). Posts a Notification Center alert when free memory
# drops below a threshold, naming the top RAM consumers so you know what to quit.
#
# IMPORTANT: this POLLS. It deliberately does NOT use `memory_pressure -l warn`,
# because that flag *applies real pressure* (allocates memory to force the system
# to the warn level — see `man memory_pressure`), which would cause the grind it
# is meant to warn about.
#
# Usage: warnmem-watch.sh [interval_secs] [free_pct_threshold]
# Run in background via the io.dlf-dds.warnmem LaunchAgent, or by hand for tuning.

INTERVAL="${1:-30}"     # seconds between samples
FREE_WARN="${2:-12}"    # notify when free memory % drops below this
COOLDOWN=300            # min seconds between notifications (anti-spam)
last_notify=0

while :; do
  free=$(memory_pressure 2>/dev/null | awk -F: '/free percentage/{gsub(/[ %]/,"",$2); print $2}')
  if [ -n "$free" ] && [ "$free" -lt "$FREE_WARN" ]; then
    now=$(date +%s)
    if [ $(( now - last_notify )) -ge "$COOLDOWN" ]; then
      swap=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+M).*/\1/')
      top=$(ps -axo rss,comm -m | awk 'NR>1 && NR<=4 {n=$2; sub(/.*\//,"",n); printf "%.0fMB %s\n",$1/1024,n}' | paste -sd', ' -)
      osascript -e "display notification \"free ${free}% · swap used ${swap} · ${top}\" with title \"⚠️ Memory pressure rising\" sound name \"Submarine\"" >/dev/null 2>&1
      last_notify=$now
    fi
  fi
  sleep "$INTERVAL"
done
