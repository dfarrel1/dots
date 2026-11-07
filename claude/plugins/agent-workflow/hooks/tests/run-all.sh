#!/usr/bin/env bash
# run-all.sh — run every hook test suite; exit non-zero if any fails.
set -u
cd "$(dirname "$0")"
rc=0
for t in ./*-tests.sh; do
  if out="$(bash "$t" 2>&1)"; then
    printf 'ok    %s  (%s)\n' "${t#./}" "$(printf '%s\n' "$out" | tail -1)"
  else
    printf 'FAIL  %s\n' "${t#./}"; printf '%s\n' "$out" | grep -E '^FAIL' | head -20
    rc=1
  fi
done
exit "$rc"
