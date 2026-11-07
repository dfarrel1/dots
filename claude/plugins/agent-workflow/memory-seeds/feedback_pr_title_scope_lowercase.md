---
name: pr-title-scope-lowercase
description: PR titles are Conventional Commits with one lowercase scope; IDs go in the subject, not the scope
metadata:
  type: feedback
---

PR titles follow Conventional Commits with a single lowercase scope (`a-z 0-9 . / _ -`):
`fix(parser): handle empty input`. Record IDs and multi-item lists go in the subject, never the scope.

**Why:** title validators reject uppercase letters and commas in the scope, and the natural temptation is to
put an uppercase ID there.

**How to apply:** `docs(findings): F-112 and F-113 resolved`, not `docs(F-112,F-113): resolved`. Keep the
title under 100 characters.
