---
name: master-worktree-readonly
description: In a repo with .claude/agent-workflow.yaml the master worktree is read-only; work happens in a per-session worktree (/iso enter)
metadata:
  type: feedback
---

In a repo that carries `.claude/agent-workflow.yaml`, never edit, commit, or switch branches in the master
worktree. `/iso enter <name>` creates `<worktrees_dir>/<name>` on `track/<name>`; all writes and git go there.

**Why:** concurrent sessions share the master worktree. A branch switch or commit there swings HEAD under
every other session, and their next commit lands on the wrong base.

**How to apply:**
- Never `git checkout -b`, `git checkout <branch>` or `git switch` in master; the git-hooks dispatcher reverts it.
- Every mutating git command is `git -C <absolute worktree path> ...`; the Bash tool's cwd does not persist.
- File tools take absolute paths under the `OPERATING_DIRECTORY` that `/iso` printed.
- Related: [[no-halfway-worktree-authoring]], [[auto-iso-enter-on-track-shaped-tasks]].
