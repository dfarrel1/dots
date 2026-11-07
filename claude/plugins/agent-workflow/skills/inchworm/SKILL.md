---
name: inchworm
description: Use BEFORE any expensive validation step — a full playbook run, a soak, a deploy, a fleet-wide scan, a CI round-trip, anything over about a minute. Also use when a fix-run-fail cycle has repeated twice, when you are about to write production-quality code against an untested hypothesis, and when a probe you wrote to answer one question is drifting toward permanence.
---

# Fast/slow inchworm

Two motions in sequence, never collapsed into one.

**Fast move** — the narrowest probe that gives a definitive yes/no to one
specific question. Throwaway quality is fine; speed is the point. Output is an
answer, not an artifact.

**Slow move** — durable codification of what the fast move learned. Production
quality. Output is an ADR, a role, a finding, a guard, a test — something the
next person reads instead of re-deriving.

## The hard rule

**Never use a long playbook run, a full soak, a deploy, or any
production-shape mechanism as the VALIDATION STEP for a hypothesis.**

The validation is the smallest possible probe. The production-shape mechanism
comes afterwards, as the codification, once you know what you are codifying.

## How to tell you are violating it

You are about to run something slow, and the thing you want out of it is an
*answer* rather than an *effect*. That is a probe wearing a deploy's clothes.

The tell in a transcript: the same expensive command run three or more times,
each time revealing exactly one new fact. Cost is N × runtime. The fast move
would have revealed all N at once.

Worked example: a 20-phase, 5-minute playbook run sixteen times, each run
surfacing one missing variable and then failing. The fast move was one command:
parse every role's assert gates and diff them against the inventory's
variables. It finds every missing input in under a second.

## Fast moves that are usually available

Before a deploy run, ask what the run would tell you, then get it cheaper:

- **Required inputs** — grep the roles' `assert` / `mandatory` / `| default('')`
  gates and diff against the group_vars. Do not discover them one failure at a time.
- **Rendered output** — render the template locally, or `--check` a single task,
  rather than converging the host.
- **Reachability, ports, certs** — `nc`, `openssl s_client`, `curl -o /dev/null -w`.
- **What is actually running** — read the object (`docker inspect`, `systemctl
  is-active`, the file on disk). A command's exit code records intent; the
  object records effect.
- **Whether a change is safe** — `git diff --stat` and grep the diff for the
  dangerous class, rather than running the thing and watching.

## Anti-patterns this forbids

- Comprehensive solution to an unmeasured problem.
- A "fast move" that becomes permanent — the throwaway probe left running.
- Slow move with no fast move first: production code on an unvalidated guess.
- Slow move skipped entirely — "I figured it out, moving on" — leaving the next
  person to re-derive it.

## The reviewer question

For any commit that is the validation step for a hypothesis and is not a small
probe: *what was the fast move, what did it tell you, and where is the slow
move that codifies it?*
