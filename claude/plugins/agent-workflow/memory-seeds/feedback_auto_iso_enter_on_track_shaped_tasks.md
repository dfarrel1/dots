---
name: auto-iso-enter-on-track-shaped-tasks
description: When a task is track-shaped (multi-commit, a PR, shared docs), run /iso enter before the first write without being asked
metadata:
  type: feedback
---

In a repo with `.claude/agent-workflow.yaml`, run `/iso enter <name>` before the first write when the task is
track-shaped, without waiting to be told.

Track-shaped means any of: more than one commit; a PR will be opened; an edit to CLAUDE.md, an ADR, a design
doc, an index file or the tracker; a long-running job; work that may span sessions. The operator saying
"land the PR for X", "fix Y end to end", "build Z" or "refactor M" is track-shaped.

**Why:** entering costs seconds; skipping it means edits in master, refused by the guards or swept into
another session's commit.

**How to apply:** name the track for the work (`fix-login-timeout`, `bump-parser-1.9`), enter, work, open the
PR, `work release <name>` after merge. If unsure, enter. Related: [[master-worktree-readonly]].
