---
name: no-halfway-worktree-authoring
description: Write files inside the per-session worktree from the start; never write to master paths and copy them across
metadata:
  type: feedback
---

Author files inside the per-session worktree from the first write. Never `Write` to an absolute
master-worktree path and then `cp` it into the worktree.

**Why:** the master copy stays behind as untracked dirt that another session's `git add -A` sweeps into its
commit, and the two copies drift.

**How to apply:** construct every absolute path from the worktree root `/iso` printed. If you find you wrote
into master, move (not copy) the file into the worktree and confirm master is clean. Related:
[[master-worktree-readonly]].
