# memory seeds

Feedback memories that back the agent-workflow plugin's mechanical guards at the reflex layer. They are not
loaded automatically: `aw-seed-memories` (agent-tools/bin, also run by `claude-adopt --seed-memories`)
copies the missing ones into the current project's memory directory and adds one index line per file to its
`MEMORY.md`. Existing files are never overwritten.

| File | Rule |
|---|---|
| `feedback_master_worktree_readonly.md` | master worktree is read-only in adopted repos |
| `feedback_no_halfway_worktree_authoring.md` | write inside the worktree from the first write |
| `feedback_auto_iso_enter_on_track_shaped_tasks.md` | `/iso enter` before the first write on track-shaped work |
| `feedback_bus_emit_at_release.md` | post what others need before `work release` |
| `feedback_findings_emit_on_record.md` | claim a record number on the bus before writing it |
| `feedback_handoff_at_pause_points.md` | `/handoff` at natural pause points |
| `feedback_no_destructive_git_without_check.md` | no destructive git without checking what it destroys |
| `feedback_pr_title_scope_lowercase.md` | one lowercase Conventional Commits scope |
