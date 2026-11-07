# git-hooks — one dispatcher for every repo

`hooks/<name>` are symlinks to `dispatch`. With git's global `core.hooksPath`
pointing at `hooks/` (`install-global --apply`), every git operation in every
repo runs `dispatch`, which:

1. in a repo carrying `.claude/agent-workflow.yaml` (and `master_readonly` not
   `false`), keeps the master worktree on the trunk (`post-checkout` reverts a
   branch checkout there, `pre-commit` refuses a commit off the trunk) and warns
   on a `track/<name>` commit without `[track: <name>]` (`commit-msg`);
2. always runs the repo's own `<common git dir>/hooks/<name>` with the same
   arguments and stdin, so pre-commit frameworks, LFS and hand-written hooks
   keep working under a global hooks path.

A repo whose own `.git/hooks/<name>` already carries the master-guard checks
keeps them and the dispatcher's copy stays silent. A repo with a local
`core.hooksPath` never reaches the dispatcher. `AGENT_GIT_HOOKS=off` skips the
dispatcher's own checks for one command; the repo's hook still runs.

```bash
agent-tools/git-hooks/install-global            # show what would change
agent-tools/git-hooks/install-global --apply    # set it
agent-tools/git-hooks/install-global --remove   # unset it
```
