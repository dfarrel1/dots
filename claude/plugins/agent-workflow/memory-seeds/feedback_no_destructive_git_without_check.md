---
name: no-destructive-git-without-check
description: Never run reset --hard, force-push, branch -D, checkout ., restore ., clean -f, worktree remove --force or stash mutations without checking what they destroy
metadata:
  type: feedback
---

Do not run `git reset --hard`, `git push --force` (use `--force-with-lease`), `git branch -D`,
`git checkout .`, `git restore .` (without `--staged`), `git clean -f`, `rm -rf .git`,
`git worktree remove --force`, or any mutating `git stash` subcommand. The destructive-git guard refuses
them; the reflex should make the guard a backstop.

**Why:** each can destroy uncommitted work without warning, and refs/stash is one ref shared by every
worktree and session, so a pop can take someone else's work.

**How to apply:** inspect first (`git status`, `git diff`). Keep work-in-progress uncommitted in your own
worktree, or commit a `/handoff` baton. Before a branch-rewriting operation note the SHA or tag it. Use the
`AGENT_ALLOW_DESTRUCTIVE_GIT=1` prefix only with the operator's confirmation.
