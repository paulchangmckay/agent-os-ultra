# pg-aiguide `postgres` skill integration

## Problem

`timescale/pg-aiguide` ships 9 opinionated PostgreSQL/TimescaleDB/PostGIS skills (schema design, indexing, hypertables, pgvector, hybrid search, safe migrations). None are installed. Installing the skill alone without wiring it into the existing routing conventions (`CLAUDE.md` §2 table, `claude-infra-reference.md`) means it sits unused — the same failure mode this repo has already hit with orphaned installs.

## Decision

Install only the `postgres` entry-point skill (not all 9 individually). It internally cross-references the other 8 via bundled `references/` files, so coverage is equivalent with one trigger point to route on.

## Changes

1. **Install:** `npx skills add timescale/pg-aiguide --skill postgres` → `~/.claude/skills/postgres/` (real copy, not a symlink — same convention as the mattpocock/taste-skill installs).

2. **`CLAUDE.md` §2** — new row in the main process table:
   > Postgres/TimescaleDB/PostGIS schema, indexing, or migration work → `postgres` skill (external, `timescale/pg-aiguide`) — leads on schema/index/data-type opinions; `senior-engineering-partner` AUDIT: mode still applies on top for security/injection

3. **`claude-infra-reference.md`** — new "External Skill Integration (pg-aiguide / timescale)" subsection, following the existing pattern used for `make-interfaces-feel-better` and `silk-design`:
   - Install command and what it covers
   - Composition rule: `postgres` skill leads on schema/index/data-type/migration opinions; `senior-engineering-partner`'s AUDIT: mode and injection/security floor still apply on top (same layering pattern as `make-interfaces-feel-better` on a taste-skill build)
   - Note that the hosted MCP doc-search server (`mcp.tigerdata.com/docs`) was deliberately NOT installed — the skill's own best-practice content is self-contained and doesn't depend on it. (Verified: only `ghost-database` reference material mentions MCP, and that's for a separate DB-provisioning service, not doc search.)

## Explicitly out of scope

- Installing the other 8 skills individually.
- Installing the hosted MCP server or Claude Code plugin bundle.
- `github-issue-first` / worktree / PR pipeline — this is a 3-file change (one external-installer skill directory, two doc edits), no code to test, same weight as prior external-skill-integration entries already merged directly to `main`.

## Verification

- `~/.claude/skills/postgres/SKILL.md` exists with expected frontmatter after install.
- New skill is NOT invokable this session (skill discovery is session-start-only, per `CLAUDE.md` §3) — confirm this is flagged to the user rather than silently assumed working.
