---
name: record-number-claims-on-the-bus
description: When you take a new record number (ADR, finding, measurement), claim it on the bus before writing the file
metadata:
  type: feedback
---

When a numbered record is about to be created, run `next-id --fetch`, post the claim with
`work bus warn "ID CLAIM: <number>, track <name>: <subject>"`, and only then write the file.

**Why:** listing the records directory shows only what has merged. Two sessions working from their own
checkouts pick the same next number, and one of them has to renumber every cross-reference.

**How to apply:** claim before any commit, push or cross-link that uses the number. A retracted record still
burns its number. Related: [[bus-emit-at-release]].
