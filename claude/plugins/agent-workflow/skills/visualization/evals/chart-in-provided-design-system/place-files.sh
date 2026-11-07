#!/usr/bin/env bash
set -eu
mkdir -p site
cat > site/tokens.css <<EOF
:root { --color-text:#1b1f24; --color-text-muted:#57606a; --color-bg:#ffffff; --color-surface:#f6f8fa; --color-border:#d0d7de; --color-primary:#0969da; --color-success:#1a7f37; --color-warning:#9a6700; --color-danger:#cf222e; --font: "Helvetica Neue", Arial, sans-serif; }
@media (prefers-color-scheme: dark) { :root { --color-text:#e6edf3; --color-text-muted:#8d96a0; --color-bg:#0d1117; --color-surface:#161b22; --color-border:#30363d; --color-primary:#4493f8; --color-success:#3fb950; --color-warning:#d29922; --color-danger:#f85149; } }
EOF
