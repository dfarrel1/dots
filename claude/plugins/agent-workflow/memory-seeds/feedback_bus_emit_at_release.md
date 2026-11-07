---
name: bus-emit-at-release
description: Before releasing a track, post to the session bus anything another session would otherwise get wrong
metadata:
  type: feedback
---

When releasing a track (`work release <track>`), decide whether other live sessions need to know anything
from the work, and post it with `work bus info|warn|urgent "<msg>"` before the release.

**Why:** per-session worktrees isolate bytes, not discoveries. A gotcha, a renumbered record, a changed
convention or a recovered outage reaches no one unless it is posted.

**How to apply:** post when you allocated a number not yet in main (`warn`), renamed or moved something others
reference (`warn`), changed shared infrastructure or found a machine-level trap (`warn`/`urgent`), or merged
work others are waiting on (`info`). Skip routine progress. The release `summary:` is the durable record; the
bus is the push to sessions awake now. Related: [[record-number-claims-on-the-bus]].
