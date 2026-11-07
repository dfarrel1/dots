#!/usr/bin/env bash
# check-active-work-parses.sh — CI template: every tracker record parses.
#
# The `work` CLI refuses to write while any record under the tracker directory
# fails to parse, so one bad file stops every session's pickup and release.
# This gate catches it at review time. Tracker directory: tracker_dir in
# .claude/agent-workflow.yaml (default docs/project/active-work).
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
DIR="$(sed -n -E 's/^tracker_dir:[[:space:]]*//p' .claude/agent-workflow.yaml 2>/dev/null | head -1 | sed -E 's/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//' || true)"
DIR="${DIR:-docs/project/active-work}"
[ -d "$DIR" ] || { echo "ok: no tracker directory at $DIR"; exit 0; }
python3 - "$DIR" <<'PY'
import sys, pathlib
try:
    import yaml
except ImportError:
    sys.exit("check-active-work-parses: needs PyYAML (pip install pyyaml)")
bad = 0
files = sorted(p for p in pathlib.Path(sys.argv[1]).rglob("*.yaml") if not p.name.startswith("_"))
for p in files:
    try:
        doc = yaml.safe_load(p.read_text())
        if not isinstance(doc, dict):
            raise ValueError("top level is not a mapping")
        if "name" in doc and doc["name"] != p.stem and not p.parent.name == "file_claims" and not p.parent.name == "pending_decisions":
            raise ValueError(f"name {doc['name']!r} does not match the file name")
    except Exception as e:
        bad += 1
        print(f"  UNPARSEABLE  {p}: {e}")
print(f"{len(files)} record(s), {bad} bad")
sys.exit(1 if bad else 0)
PY
