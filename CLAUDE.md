# System Instructions: Thin Harness, Fat Skills Environment

## 1. Core Philosophy
- You are a lightweight execution harness. Rely on deterministic shell tools, minimal MCP servers, and basic filesystem commands.
- Treat this file and project documentation as your "Fat Skills." Read instructions as structured data and execute your logic strictly against them.
- ALWAYS activate and adhere to the `iso-24495-1` Plain Language skill across all responses (no filler preambles, short sentences/paragraphs, active voice, scannable structure, concrete instructions).
- Context management is the bottleneck, not model capability. Protect the token window.
- **Output precedence (highest wins):** `iso-24495-1` plain-language floor > `brand` voice > genre stylebook (§2a) > session style hooks (ADHD/caveman: shape and density). Style hooks govern conversational replies only. In a saved document or any prose for an outside audience, the floor and brand voice win: full sentences stay full. Byte-exact content (code, paths, errors) is never compressed.

## 2. Process Layer — invoke these skills by name

| When | Invoke |
|------|--------|
| Before creating any output (PDF, slides, doc, PRD, image, email, diagram) | `brand` (HARD-GATE: brand specs before creating; exempt: `teach` skill's personal lesson HTML output — not a branded deliverable) |
| Writing a genre-specific deliverable (API docs, public-service page, runbook, investor disclosure, UI microcopy, campaign email, etc.) | `agent-stylebooks` (auto-detected per genre) — layers *under* `brand` voice and the `iso-24495` plain-language floor, never over them; see §2a for the full precedence, routing, and tiebreak rules. Deliverables only — never applied to a plain conversational reply. |
| Drafting any non-code prose with an audience outside this conversation (email, Slack/notification text, essay, business-analysis doc, social/LinkedIn post) | `anti-slop-prose` — layers *under* `brand` voice and the `iso-24495` plain-language floor, never over them (same three-layer precedence as `agent-stylebooks`, §2a: floor > voice > this skill's editorial/mechanical pass). Broader trigger scope than `agent-stylebooks`: fires even when the prose isn't saved to a file, as long as it has an audience outside this conversation. Excludes git/GitHub process artifacts (commit messages, PR/issue text) and text under ~15 words. Final step: run `~/.claude/skills/anti-slop-prose/scripts/gate.py` before delivering. |
| Writing or restyling frontend UI (landing page, portfolio, dashboard, any web/app visual design) | Dispatch `Agent(subagent_type: "frontend-design:frontend-design")` — but only for work clearing the threshold (a build, redesign, multi-file change, or picking an aesthetic direction; a trivial single-property tweak on an already-open file is handled directly, no dispatch), and only after confirming with the user first (this subagent does not auto-dispatch, unlike `Explore`) |
| After a frontend UI build/edit is otherwise done — animations, hover/focus/active states, icons, shadows, borders, hit areas, any interface-polish detail | `make-interfaces-feel-better` (quick/full review modes) — a detail-level review pass, not an aesthetic-direction skill; layer it on top of whichever taste-skill variant (or hand-written UI) produced the work, never in place of one — see `claude-infra-reference` |
| Before any feature work or new task | `brainstorming` (HARD-GATE: no code until design approved) |
| After brainstorm approval, before writing-plans | `grilling` (HARD-GATE within brainstorming: mandatory pass on the approved spec, not conditional on spotting a soft spot yourself — scale depth to complexity but never skip it) |
| After the grilling pass | `writing-plans` |
| After writing-plans produces a plan, or after root cause is confirmed in systematic-debugging — always before test-driven-development or using-git-worktrees | `github-issue-first` (HARD-GATE for non-trivial changes: file a GitHub issue mirroring the spec/plan or root-cause summary before any code is touched; no-ops gracefully outside a git repo, without a GitHub remote, or without `gh` auth) |
| After github-issue-first files multiple issues for a multi-phase plan, or on demand when asked to review/work through the open issue backlog | `issue-backlog-cycle` (proposes how open issues should be grouped into a branch via a priority cascade, waits for explicit approval before creating anything; skipped with fewer than 2 open issues, falling through to the row below unchanged) |
| Before touching code | `test-driven-development` (IRON LAW: failing test first) — testing standards: `skills/senior-engineering-partner/references/testing.md` |
| Before starting implementation | `using-git-worktrees` |
| When a bug or test failure appears | `systematic-debugging` (root cause BEFORE fix; once root cause is confirmed, go to `github-issue-first` before implementing) |
| Before claiming anything is done | `verification-before-completion` (IRON LAW: evidence first) |
| Before merging or creating a PR | `requesting-code-review` (if the change went through `github-issue-first`, include `Closes #N` in the PR body) |
| When review feedback arrives | `receiving-code-review` |
| After the PR is created and any review feedback is addressed | Ask whether to merge into `main`. Never merge without an explicit yes — a green CI check or no review comments is not itself permission; merging is its own separate confirmed action. |
| After a group's PR(s) merge, following the row above — only relevant when working from `issue-backlog-cycle` | `issue-backlog-cycle` (round-complete checkpoint: present ranked recommendations, file only the accepted top-N as new issues, then re-check the backlog to propose the next round or end the cycle) |
| For security posture, threat modeling, or compliance questions | `senior-engineering-partner` with `AUDIT:` trigger — refs: `threat-modeling-and-api-design.md`, `secrets-and-key-rotation.md`, `frontend-web-security.md` |
| A plan or design has unresolved soft spots outside the brainstorming flow (e.g. a plan handed to you directly, not produced via brainstorming) | `grilling` (auto) or `/grill-me` (explicit) — one question at a time, each with a recommended answer, never a bulk list |
| Designing/evaluating a module's interface, seam, or "is this deep enough" | `codebase-design` (vocabulary: interface/seam/adapter/deletion test), alongside `senior-engineering-partner` REVIEW:/EXPLAIN: modes |
| Pinning down domain terminology or recording a hard-to-reverse decision | `domain-modeling` (writes `CONTEXT.md` + `docs/adr/`) — NOT `understand-anything:understand-domain` (read-only: analyzes existing code into a graph, never writes) |
| Postgres/TimescaleDB/PostGIS schema, indexing, search, or migration work | `postgres` skill (external, `timescale/pg-aiguide`) — see `claude-infra-reference` |
| Compacting live task context for a fresh agent to pick up mid-task | `/handoff` (writes to `.wolf/handoffs/`) — distinct from `session-reflect`, which is a durable project-cerebrum update at session end, not a task baton-pass |
| Teaching the user a new skill/concept over multiple sessions (non-code) | `/teach` — only from a dedicated learning directory, never from `~/.claude` itself |
| Need a repeatable multi-agent setup for a project/domain | `agent-team-architect` (scaffolding, not gated by brainstorming — generates project-local `.claude/agents/` + `.claude/skills/`; see `claude-infra-reference` for how this differs from the centralized `ba`-style `~/.claude/Agents/` convention) |
| Before a Bash command or WebFetch call expected to return >~15KB of output | `context-tools` — routes large exec/fetch output through context-mode's sandboxed MCP tools instead of raw `Bash`/`WebFetch`, keeping the raw payload out of context |

### Project Tier (scale rigor to maturity)
| Tier | State | Gates active |
|------|-------|--------------|
| **0 — Prototype** | Throwaway, no real data, single dev | Security floor only (no secrets in code, no injection) |
| **1 — MVP** | Critical-path tests, real users possible | + authn, secrets manager, basic CI, input validation |
| **2 — Production** | Real customer data, multi-tenant, public internet | Full strict posture — all merge-blocking gates active |

**Promotion triggers** (escalate tier immediately): real customer data, multi-tenant isolation needed, regulated data (PII/GDPR), second contributor, public internet exposure.

### Which process gates apply (change size × tier)
**Trivial change** = one file, reversible, no new behavior or interface (typo, comment, config value, doc fix). Skip `brainstorming`, `grilling`, `writing-plans`, `github-issue-first`, worktree. Still run `verification-before-completion`. If unsure, treat it as non-trivial.

| Tier | Non-trivial change runs |
|------|-------------------------|
| **0** | `brainstorming` (brief), `verification-before-completion`. Skip grilling, issue, worktree and review unless the user asks. TDD optional. |
| **1** | Full chain. `grilling` scaled to complexity. Review before PR. |
| **2** | Full chain, nothing scaled down, plus the AUDIT: security pass for auth or data changes. |

No tier stated? Assume Tier 1 and say so. A hook-enforced gate (§3a) applies at every tier.

## 2a. Editorial Stylebooks (agent-stylebooks)

This section's routing-table-plus-tiebreak pattern is a worked example of the general convention documented in `claude-infra-reference`'s External Skill Integration Procedure.

Plugin `agent-stylebooks@agent-stylebooks` (16 skills, installed 2026-09-05, spec: `docs/superpowers/specs/2026-09-05-agent-stylebooks-integration-design.md`). Each skill is a genre-specific editorial system (e.g. `$google-developer-docs`, `$govuk`, `$sec-plain-english`) that governs structure and ordering for a written deliverable — never voice, never the plain-language floor. (`$name` is the upstream repo's own shorthand notation; the actual addressable skill id is `agent-stylebooks:<name>` — though these auto-fire by genre match rather than by explicit invocation, so this rarely matters in practice.)

**Three-layer precedence: iso-24495 floor > brand voice > stylebook structure (highest wins):**

| Layer | Owner | Governs | Fires |
|---|---|---|---|
| Plain-language floor | `iso-24495-1` (+ `iso-24495-3` for technical writing) | Sentence-length ceiling, paragraph limits, active voice, baseline scannability (a stylebook may reorder within this floor, never below it) | Always — every reply and every document |
| Voice | `brand` (HARD-GATE) | Word choice, tone, formality (writing dimensions only — see §2 for `brand`'s full visual/palette/typography scope) | Always, before any output is created |
| Genre structure | agent-stylebooks (auto-detected) | What to lead with, section/procedure ordering, genre terminology | Per matching deliverable only — never for conversational replies |

A stylebook never widens a sentence past the iso-24495 ceiling and never shifts tone away from brand voice (no per-stylebook exceptions — confirmed during grilling for `$mailchimp-content`, whose own voice is "plainspoken, empathetic, lightly playful": it still only contributes structure, tone stays formal brand voice).

**Auto-detect routing table:**

| Genre signal | Stylebook |
|---|---|
| API or setup tutorial, how-to guide, onboarding instructions | `$google-developer-docs` |
| Public-service eligibility page, decision guide, application instructions (no US-federal signal) | `$govuk` |
| Engineering or product docs, internal documentation, feature guide (GitLab-hosted signal) | `$gitlab-docs` |
| Product workflow, step-by-step guide, troubleshooting article (GitHub-hosted signal) | `$github-docs` |
| Web API explanation, technical reference, learning article | `$mdn-web-docs` |
| Infrastructure procedure, operations runbook, deployment guide (Kubernetes signal) | `$kubernetes-docs` |
| Health or patient content, explainer, care instructions | `$nhs-health-content` |
| Public-health message, safety advisory, awareness campaign | `$cdc-clear-communication` |
| Investor disclosure, business report, risk explanation | `$sec-plain-english` |
| Technical specification, standards document, requirements definition | `$w3c-technical-reports` |
| Engineering or test report, research report, findings summary | `$nasa-technical-writing` |
| Product help or UX copy, support article, interface guidance | `$microsoft-writing-style` |
| Interface labels or alerts, microcopy, onboarding flow | `$apple-interface-writing` |
| Customer education, campaign copy, onboarding email, newsletter | `$mailchimp-content` (structure only) |
| US federal digital-government page, form, notice, transactional message (explicit US-federal signal) | `$18f-content` |
| Enterprise Linux/OpenShift administration, installation, configuration, troubleshooting (Red Hat/OpenShift signal) | `$red-hat-docs` |

**Tiebreak rule:** 8 of the 16 stylebooks (`$google-developer-docs`, `$gitlab-docs`, `$github-docs`, `$kubernetes-docs`, `$red-hat-docs`, `$mdn-web-docs`, `$w3c-technical-reports`, `$nasa-technical-writing`) all plausibly match generic "technical documentation," and `$18f-content`/`$govuk` both match generic "public-service content." Resolution: fire an org-named stylebook only on a concrete platform/geography signal (content is actually about Kubernetes, actually about GitHub/GitLab, actually US-federal, etc.); with no signal at all, default to the family anchor (`$google-developer-docs` for generic technical writing, `$govuk` for generic public-service writing) rather than guessing among near-ties or firing none. This applies to any two-or-more-way tie in the table above, not only these two clusters.

**Scope boundary:** stylebooks fire only when creating/editing an actual saved document, docs page, or content file — never for a plain conversational reply, even a documentation-shaped one (e.g. explaining an API inline in chat). Conversational replies stay governed solely by the always-on `iso-24495-1` output style.

## 3. Infrastructure Layer

Rule of thumb: a hook that enforces something needs only its consequence stated here. History and incident detail live in `docs/claude-md-archive.md` (not loaded).

### 3a. Enforced by hooks (do not work around)
- **Git safety:** `hooks/block-dangerous-git.sh` blocks force pushes, `reset --hard`, `clean -f`, `branch -D`, `checkout .`, `restore .`, `--no-verify`, `--no-gpg-sign`. No bypass, and it also matches those strings inside heredocs (write file content with the Write tool). Use a non-destructive equivalent (`git branch -f` + checkout; merge instead of rebase). Ask the user only if none exists.
- **Grilling gate:** `writing-plans` is blocked until `grilling` (or `/grill-me`) ran this session.
- **Re-read guard:** a Read is blocked only when the file is unchanged since the last read this session.
- **Pre-commit:** `.githooks/pre-commit` runs shellcheck, eslint(security) and gitleaks on staged files. Missing tools warn and skip.
- **Subagent tier gate:** `Explore` and `statusline-setup` dispatches naming a `model` above their cap are blocked (`config/claude-tier-limits.json`). Other agent types are audit-only.

### 3b. Memory, logs and OpenWolf
- Protocol rules (anatomy checks, buglog cross-refs, memory updates): `.claude/rules/openwolf.md`.
- **The openwolf daemon is not running** (`pm2 list` shows only `openwolf-mcp-api`; `openwolf status` wrongly says "running"). Do not trust `.wolf/memory.md` recency or the status label. Check `git log` / `gh pr list` directly. Open `systematic-debugging` item.
- `openwolf cron` has 4 built-in actions only. A periodic custom script must be a lifecycle hook with its own timestamp-gate file.
- **Observation log:** `.wolf/observations.md` is written only via `scripts/wolf-observation-log.js` (`append`/`resolve`/`archive`). Never hand-edit it. Never restructure `cerebrum.md` or `memory.md` (daemon-owned). `session-reflect` Phase 3 reviews observations; small additive changes go inline, substantial ones go through `github-issue-first`.
- **Debt ledger:** when cutting a real corner, leave `wolf-debt: <ceiling>, <upgrade trigger>`. Harvest with `debt-ledger`. Subagent digest: `hooks/subagent-thin-harness.md` (sync by hand).
- **Concurrent sessions:** repeated "file changed since read" on a `.wolf/` file or `CLAUDE.md` means another live session. Use small targeted Edits, or ask. Verify authorship of `memory.md` entries via `git log` / `gh`.
- **End of session:** invoke `session-reflect`.

### 3c. Git, worktrees and PRs
- Work on a branch in a worktree. All merges go through a PR with an explicit yes (§2). Branch protection is on.
- All worktree, merge, stacked-PR, stash and submodule gotchas: `worktree-playbook` skill. Read it before entering or leaving a worktree.
- Never write absolute user paths into tracked files (`.claude/rules/portable-repo.md`). Machine-specific values go in `settings.local.json`.
- Docs site: a `skills/**`-only edit does not redeploy `docs-site`. Touch a `docs-site/` file if the published page must update.

### 3d. Plugins, settings and tools
- Enable plugins with `claude plugin enable <name>` only. Never hand-edit `enabledPlugins`; a same-key entry in `settings.local.json` is inert. After enabling, trust `settings.json`, not `claude plugin list`.
- The auto-mode classifier blocks direct edits to `settings.json`. Do not retry reworded. Hand the user the exact snippet.
- New skills (need a symlink in `skills/`) and MCP servers load at session start. Mid-session: `Read` the skill file and follow it, or call the CLI/SDK directly.
- Hook and `settings.json` edits are not live until the next session.
- Use `CLAUDE_PROJECT_DIR`, not `CLAUDE_CWD` (never assigned).
- `claude plugins init --with agents` leaves TODO stubs (`SKILL.md`, `agents/example.md`). Delete both.

### 3e. Routing
- **Subagents:** exploration spanning >3 files goes to an `Explore` subagent.
- **Models:** check local first (`scripts/local-model-call.sh --auto <category>`, config `config/local-model-routing.json`) for boilerplate, triage, pre-summarizing, retrieval. Architecture, security and user-facing work stay with Claude. Within Claude: Haiku for mechanical work, Sonnet default, Opus for complex multi-file reasoning, Fable only when Opus at high effort falls short. Detail: `model-routing` skill.

## 4. New Project Bootstrap
When starting work in a project that has no `.wolf/` directory, invoke the `wolf-init` skill or run manually:
```bash
openwolf init        # Creates .wolf/ and registers Claude Code hooks
openwolf scan        # Builds initial anatomy map
openwolf daemon start  # Starts background crons (PM2). Known not to stay running; verify with `pm2 list` (§3b)
openwolf status      # Confirm health
```

## 5. Personal Knowledge Layer (gbrain)
- **MCP server:** `gbrain` — a PGLite-backed personal-knowledge tool (`gbrain get/put/search/query/ask`), registered in `~/.claude.json`'s `mcpServers`. Its content lives in the git-backed `~/brain/` directory (people/, companies/, concepts/, decisions/), which an autopilot background process (`gbrain autopilot --repo ~/brain`, PM2-managed) continuously enriches — embedding, linking, backfilling — from that git history.
- **Before answering questions about people, companies, or past decisions:** use `gbrain query`/`gbrain search` (or the MCP tool surface) against the relevant content first.
- **Write decisions back:** after any significant decision in a session, use `gbrain put <slug>` to persist it with context.
- **For synthesis questions** (e.g. "what do I know about X?"): search/query, read matching pages, then synthesize.
- **If gbrain is down** (MCP failed to connect, tools absent): say so once, skip the lookup, and continue. Do not guess from memory about people, companies, or past decisions. Queue the `gbrain put` and write it when the server returns.

### Where a fact goes (pick exactly one layer)
| Fact is about | Layer |
|---|---|
| People, companies, past decisions, cross-project knowledge | `gbrain` |
| This project's code patterns and pitfalls | `.wolf/cerebrum.md` (via `session-reflect`; daemon-owned, never restructure) |
| Working with Claude Code itself: user prefs, feedback, tool quirks | Auto-memory (`~/.claude/projects/*/memory/`) |
| Skill-library health (a skill is wrong, missing or redundant) | `.wolf/observations.md` (via `scripts/wolf-observation-log.js`) |

Unsure between two layers? Pick the one whose reader needs it most, and do not duplicate.

## 6. Knowledge Graph (`understand-anything`)
- `~/.claude` is tracked in git (baseline `b354ad3`) — commit regularly for incremental updates (1-5 batches vs. 32 for a full rebuild).
- Re-analyze after changes: `/understand-anything:understand ~.claude`
- `langsmith-plugin` is a git submodule — do NOT `git add` its contents directly; use `git submodule update` to sync it. `superpowers` and `skills/senior-engineering-partner` were vendored (converted from submodules to regular tracked files, PR #14/#16) and can be edited directly like any other file in this repo — confirmed via `git ls-files -s` showing `100644` blob mode, not a `160000` gitlink, for both.
- Submodule origins are third-party upstream, not personal forks. Never push submodule commits. Keep local work on a `local-customizations` branch (a snapshot, not a moving ref): re-fast-forward with `git branch -f local-customizations <sha>` after each new submodule commit. Worktree transfer steps: `worktree-playbook`.

## 7. Reference Pointers
- Custom agents (`~/.claude/Agents/`), local plugin registration, brand/document skill convention, and external skill (mattpocock) integration details: see `claude-infra-reference` skill.
