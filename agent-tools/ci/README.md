# CI templates

Gates that cannot be global, for a repo to copy into its own CI. `claude-adopt --ci`
copies them to `.github/agent-workflow/` and writes a workflow that runs them.

| Script | Gate |
|---|---|
| `check-claude-md-size.sh` | CLAUDE.md stays under a trip line (35 000 bytes; curate to 25 000) |
| `check-no-agent-references.sh` | no claude.ai / Claude-Session: / anthropic.com references outside tooling paths, in files or in a commit range |
| `check-active-work-parses.sh` | every `work` tracker record parses |
| `agent-workflow.yml` | GitHub Actions workflow running the three on pull requests |
