---
name: handoff-at-pause-points
description: Run /handoff at natural pause points without waiting for a hook nudge
metadata:
  type: feedback
---

Run `/handoff` whenever in-head state is about to be lost: before a long background task, before leaving
plan mode with work in progress, before `/clear` or `/iso exit`, at a permission halt, and at any "done for
now" moment. Do not wait for the PreCompact / SessionEnd / Stop nudge.

**Why:** one extra commit per pause; the next session resumes in minutes instead of reconstructing context.

**How to apply:** on a `track/<name>` branch with uncommitted work, write the `wip(<track>): handoff baton`
commit the skill describes. On a clean tree whose last commit says what is next, it is a no-op. Related:
[[master-worktree-readonly]].
