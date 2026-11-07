# agent-workflow (Claude Code plugin)

Hooks, skills and memory seeds for running several Claude Code sessions on one
repo without collisions. What runs where, the knobs, and how to switch it on:
[claude/README.md](../../README.md) in the dots repo.

Skills: `bus`, `closeout`, `coldstart`, `claude-md-frugality`, `design-work`,
`handoff`, `inchworm`, `iso`, `loose-end`, `visualization`.

Install: `/plugin install agent-workflow --marketplace dfarrel1/dots`, or from a
local checkout, `claude plugin marketplace add <dots checkout>` then
`claude plugin install agent-workflow@dots`.
