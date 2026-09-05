# pg-aiguide `postgres` skill integration

## Problem

`timescale/pg-aiguide` ships 9 opinionated PostgreSQL/TimescaleDB/PostGIS skills (schema design, indexing, hypertables, pgvector, hybrid search, safe migrations). None are installed. Installing the skill alone without wiring it into the existing routing conventions (`CLAUDE.md` §2 table, `claude-infra-reference.md`) means it sits unused — the same failure mode this repo has already hit with orphaned installs.

## Decision

Install only the `postgres` entry-point skill (not all 9 individually). It internally cross-references the other 8 via bundled `references/` files, so coverage is equivalent with one trigger point to route on.

## Changes

1. **Install:** `npx skills add timescale/pg-aiguide --skill postgres` → `~/.claude/skills/postgres/` (real copy, not a symlink — same convention as the mattpocock/taste-skill installs).

2. **`CLAUDE.md` §2** — new row in the bottom "topic-triggered reference" cluster (rows 29–36: `senior-engineering-partner` AUDIT, ad-hoc `grilling`, `codebase-design`, `domain-modeling`, `/handoff`, `/teach`, `agent-team-architect`, `context-tools`), placed immediately after the `domain-modeling` row — NOT in the pipeline cluster (rows 13–28), and NOT with the composition rule spelled out inline:
   > Postgres/TimescaleDB/PostGIS schema, indexing, or migration work → `postgres` skill (external, `timescale/pg-aiguide`) — see `claude-infra-reference`

3. **`claude-infra-reference.md`** — new "External Skill Integration (pg-aiguide / timescale)" subsection, following the existing pattern used for `make-interfaces-feel-better` and `silk-design`:
   - Install command and what it covers
   - Composition rule: `postgres` skill leads on schema/index/data-type/migration opinions; `senior-engineering-partner`'s AUDIT: mode and injection/security floor still apply on top (same layering pattern as `make-interfaces-feel-better` on a taste-skill build)
   - Note that the hosted MCP doc-search server (`mcp.tigerdata.com/docs`) was deliberately NOT installed — the skill's own best-practice content is self-contained and doesn't depend on it. (Verified: only `ghost-database` reference material mentions MCP, and that's for a separate DB-provisioning service, not doc search.)
   - Note the `--copy` install also writes a duplicate to `~/.agents/skills/postgres` (a separate, non-git home directory used by other agent tools) — a side effect of the CLI, not something to clean up.

## Explicitly out of scope

- Installing the other 8 skills individually.
- Installing the hosted MCP server or Claude Code plugin bundle.

## Process

This goes through the full pipeline, not a direct-to-main edit: `github-issue-first` → `using-git-worktrees` → PR → explicit merge approval. Verified against precedent — both prior external-skill-integration doc changes (`make-interfaces-feel-better`, `silk-design`) landed via PR (#24, #65, #73), and `main` has branch protection active (`enforce_admins: true`, PR required, confirmed via `gh api .../branches/main/protection`) — a direct push would be rejected regardless.

## Verification

- `~/.claude/skills/postgres/SKILL.md` exists with expected frontmatter — already confirmed during grilling (installed for real: `npx skills add timescale/pg-aiguide --skill postgres --global --copy -y` succeeded for Claude Code, and the skill was immediately invokable via the Skill tool in the same session — no restart needed).
- `CLAUDE.md` and `claude-infra-reference.md` edits land on a worktree branch, verified there, then merged via PR per the Process section above.
