# Project Instructions and Agent Routing

The local filesystem is case-insensitive, so `AGENTS.md` also contains the routing information that would otherwise live in `agents.md`.

## Purpose

Build a small, credible service-desk portfolio project using PowerShell, Microsoft Graph and Azure tooling.

## Standards

- PowerShell 7, approved verbs, strict mode and terminating error handling.
- Safe defaults: read-only operations unless a command explicitly supports `-WhatIf`.
- Never commit tenant IDs, credentials, tokens, user records or exported production data.
- Pester tests must cover parsing, diagnostics and report generation.
- GitHub Actions must run formatting/static analysis and tests.
- Documentation uses plain British English and only claims verified behaviour.
- Infrastructure uses Bicep and must pass a validation/build check before release.

## Workflow

- Keep changes small and testable.
- Update `context.md` and `memory.md` at meaningful milestones.
- Record architecture decisions under `docs/adr/`.
- Use red for warnings and green for successful checks where terminal colour is supported.

## Routing

- Repository architecture and safety decisions: strongest reasoning model.
- PowerShell implementation and tests: routine coding agent.
- Bicep and CI verification: routine infrastructure agent.
- CV wording: evidence review after the repository is verified and public.

Use Ruflo only when work is deliberately split across isolated agents. Do not use multiple agents for small changes.

