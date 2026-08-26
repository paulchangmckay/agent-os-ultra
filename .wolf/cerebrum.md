# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-08-17

## User Preferences

- Wants "why" before implementation — rationale first, then act.
- Prefers ranked/prioritized lists over exhaustive surveys.
- Invests in foundational tooling deliberately — not a distraction from feature work.
- Consolidate over proliferate: merge overlapping tools/skills/gates into existing ones. When installing a third-party skill/plugin, wire it into CLAUDE.md's Process Layer table so it's actually used.
- Combined skill design: auto-always for internal/Claude-facing targets (cerebrum), conditional+approval-gated for shared/team targets (CLAUDE.md).
- Wants impact-on-functionality explained before accepting config changes to background services.
- For multi-part audit/cleanup decisions with trade-offs, consistently picks the "Recommended" option (confirmed 4x) — safe to lead with a strong recommendation.
- Prefers Anthropic document-skills plugins over calling underlying libraries directly.
- Has a defined personal brand (Brand Style Guide v3) — every output goes through `/brand`; never hardcode brand values elsewhere.
- Prefers `/ba` flow keep the doc-type prompt (all/pptx/docx+pdf/skip).
- Wants print-quality PNGs (≥2300px, `--scale 3`) as default for BA diagram renders.

## Key Learnings

### Project: .claude — Skills, Plugins, Config
- Superpowers skills live in `~/.claude/superpowers/skills/` but must be symlinked into `~/.claude/skills/` to be invocable (bug-195, fixed 2026-07-27). New symlinks, `claude plugin install`/`mcp add`, and hook/settings.json edits are NOT live until session restart, including inside worktrees. Same-session workaround: Read the skill file directly, or call the SDK/CLI directly for MCP.
- Plugin enable state lives only in `settings.json`'s `enabledPlugins` — a matching `settings.local.json` entry is silently inert. Always use `claude plugin enable <name>`.
- `settings.json` has no top-level `mcpServers` key — use `~/.claude/mcp_servers.json`. Auto-mode classifier blocks direct `Edit` on the **live main checkout's** `settings.json` — hand the user the exact snippet instead of retrying. This block does NOT apply to a worktree's own copy of `settings.json`: direct `Edit` calls there succeed normally (confirmed while wiring the adhd-caveman hook, PR #59) — it's specifically the session-governing file that's gated, not every file named `settings.json`.
- `claude plugin enable/disable <name>` resolves at **user scope by default**, bypassing worktree isolation entirely — it writes straight to the live main checkout's `settings.json` regardless of the session's cwd, unlike `Edit`/`Write` (which the worktree-path-guard hook blocks for off-worktree absolute paths). Discovered when a `claude plugin disable` run from inside a worktree silently disabled a plugin live, mid-branch, before the branch had even merged — and the same guard then blocked the obvious fix (`claude plugin enable` to revert). No CLI flag observed to force project/worktree scope; treat any `claude plugin enable/disable` run from a worktree as a live, immediate change to the user's actual running config, not a branch-scoped edit — surface it to the user rather than assuming it's safely contained.
- `CLAUDE_CWD` is never assigned — always resolves to default. Use `CLAUDE_PROJECT_DIR`.
- YAML frontmatter `description:` containing `: ` must be quoted; custom skills must be directories (`skills/<name>/SKILL.md`) — flat `.md` files are silently ignored.
- `openwolf cron` only supports 4 built-in action types — use a lifecycle hook with a timestamp-gate file for custom scripts.
- `.wolf/memory.md` is a shared, live log across concurrent sessions — verify authorship via `git log`/`gh pr list`, don't assume by timestamp.
- Browser automation: use the `playwright` MCP server (WebFetch doesn't hit localhost), not `html-export`'s own pipeline, for interactive verification.
- `claude plugins init <name> --with agents` scaffolds a placeholder top-level `SKILL.md` and `agents/example.md`, both left as unedited "TODO" stubs — these don't match the working reference pattern (`ba-agent`'s actual on-disk shape: only `.claude-plugin/plugin.json` + `agents/<name>.md`, no top-level skill file). Delete both stub files rather than committing them; verify against `ba-agent`'s real structure before assuming the CLI's default output is the target shape. Confirmed 2026-08-19 building `frontend-design` (issue #55).

### Git / Worktree / Submodule Patterns
- Merge pattern: `ExitWorktree` (keep) → push branch → `gh pr create` → explicit user approval → `gh pr merge --squash` → `git pull origin main` (or `git merge origin/main` if local main has unpushed commits) → `git worktree remove --force` → `git branch -d`. `gh pr merge` can fail on branch-protection `strict` checks even when `mergeable: MERGEABLE` — fix via `git merge origin/<base>`, push, retry. Confirm landing with `gh pr view --json state,mergedAt`, not just "CI green."
- Right after `EnterWorktree`: it branches from `origin/<default>`, not local main, so unpushed local-main commits are invisible — `git rebase main` inside the worktree first. Absolute-path edits still write to the MAIN working tree — use relative paths or `cd` in. `docs/superpowers/plans/` is gitignored — copy plan files in manually. `git worktree remove` needs `--force` even for merged branches. `EnterWorktree` only targets the session's primary repo; use plain `git worktree add` for a secondary project.
- `EnterWorktree` targets the session's **launch directory**, not `~/.claude` unconditionally — if the session starts in a non-repo parent (e.g. `/Users/paulmckay` with `~/.claude` as a git repo one level down), it errors outright ("not in a git repository and no WorktreeCreate hooks are configured") instead of falling back to the nested repo. Fix: fall back to plain `git worktree add <path> -b <branch> origin/<base>` via Bash, same as the documented "secondary project" case — this scenario hits the identical fallback even though `~/.claude` itself is the primary repo, just not the launch dir. Confirmed 2026-08-19 during issue #55 work.
- Fresh worktrees don't auto-initialize submodules — check `git -C <submodule> branch --show-current`, run `git submodule update --init` if empty. To move a commit from a worktree's submodule clone to main: branch it in the source clone, `git fetch <path> <branch>`, `git branch -f local-customizations FETCH_HEAD` (automated by `scripts/submodule-transfer.sh`). Third-party submodule `origin` isn't the user's fork — never push, use the local backup branch.
- Dispatched subagents (and global-install CLIs like `npx skills add --global`) can silently escape worktree isolation via absolute paths — give explicit relative-path instructions plus `pwd`/`git branch --show-current` checks before/after every write, and independently re-verify commits from the controller side.
- Merge-time conflicts: capture stash SHA before merging, reapply by exact SHA (never bare `pop`); resolve append-only logs by concatenation, regenerated inventories via `--ours` + rescan. `.wolf/buglog.json` ID collisions across branches: dedup on a content key (`timestamp+error_message+file`), confirm one side is a strict superset programmatically.
- A squash-merged PR shows as an **add/add conflict** (not a normal 3-way modify) when merging origin/main back into a local main that independently committed the same file earlier and unpushed — squashing discards the shared commit ancestry, so git sees two unrelated additions of the same path even though the content is nearly identical. Resolve by taking whichever side is the final reviewed version (usually origin's, post-squash) with `git checkout --theirs <path>`, not a manual diff-merge.

### Process / Tooling
- 2026-08-19: To verify a Claude Code hook's actual payload fields or output-delivery channel (e.g. does `PostToolUseFailure` send `error` or `tool_error`? does stdout+exit(0) reach the model, or does this event need stderr+exit(2)?), run `strings` on the installed CLI binary (`~/.local/share/claude/versions/<ver>`) and grep for the event name or `"Input to command is JSON with..."` — this surfaces the CLI's own embedded contract docs, authoritative over a subagent's claimed doc lookup or training-data assumption. Caught 2 real bugs this session that a `claude-code-guide` subagent got wrong when asked directly (wrong field name, wrong output channel) for `hooks/post-read-failure-rescue.js`.
- `node --test` needs explicit file paths, not bare directories.
- PreToolUse "did someone else write this" hooks need their baseline updated by a companion PostToolUse hook, never self-recorded in PreToolUse.
- Any hook-built filesystem path from a harness-supplied identifier needs strict allowlist sanitization before `resolve()`/`join()` — path traversal risk otherwise.
- `pipx`/`pip` can silently backtrack to a very old package version when an unpinned install's extras lack wheels for the current Python — verify actually-installed version, not just exit code.
- `understand-anything` (vendored plugin, edit upstream not here) gotchas: inside a worktree it silently redirects graph output to the main checkout unless `UNDERSTAND_NO_WORKTREE_REDIRECT=1` is set (prefix on every bash call, doesn't persist across calls); `merge-batch-graphs.py` only accepts `batch-N.json`/`batch-N-part-K.json` filenames — a differently-named merged-graph file silently drops nodes/edges with no error, so use a numeric placeholder like `batch-9000.json`; an incremental update only re-analyzes files already in the cached `scan-result.json` inventory, so compare its file count against the live repo before trusting an incremental run as complete.

## Do-Not-Repeat

- Do NOT hardcode brand values outside `brand-guide.md`, even as a "helpful reminder."
- Do NOT duplicate protocol enforcement between CLAUDE.md and `.claude/rules/openwolf.md` — single pointer, full rule in the rules file.
- Do NOT run `git checkout main` from inside a worktree — exit first.
- Do NOT modify files under `~/.claude/plugins/cache/` — third-party, overwritten on update; wrap instead.
- Do NOT use grep `--exclude-dir=<basename>` to exclude a submodule path repo-wide — matches basename anywhere. Read paths from `.gitmodules`, filter by full-path prefix.
- Do NOT chain edits to external-project files without a Read-verify step when OpenWolf hooks are active — hooks can silently revert edits.
- Do NOT trust a `cd` in one parallel Bash call to carry over to a sibling call — each runs its own subshell.
- Do NOT retry `Write` (full-file replace) against a file another live session is actively appending to — use targeted `Edit` scoped to untouched lines.
- Do NOT build agents/tooling under `~/` — always under `~/.claude/`.
- Do NOT skip test/sample files mentioned in a spec — create them during the build.
- Do NOT use `$CLAUDE_PROJECT_DIR` to resolve a script's own path inside a hook registered in `~/.claude/settings.json` — that config is user-scope and the hook fires for every project's sessions, not just `~/.claude`'s. `CLAUDE_PROJECT_DIR` resolves to whatever project is currently active, breaking the hook everywhere else. Use `$HOME/.claude/...` (settings.json command) and resolve any sibling paths from `CLAUDE_CONFIG_DIR`/`os.homedir()` inside the script instead — matches existing precedent in `hooks/session-start.sh`. Caught by a final-review subagent on the adhd-caveman hook (PR toward issue #56), not by planning or task review.
- Do NOT trust a hook's `settings.json` command wiring that passes tool-specific data via `"${SOME_ENV_VAR:-default}"` substitution without verifying the var actually exists (see Process/Tooling `strings`-on-binary entry above). `hooks/pre-read-check.js`'s `${TOOL_INPUT_PATH:-}` referenced a variable that doesn't exist anywhere in Claude Code — it silently no-op'd the entire re-read gate since the hook was first written, confirmed empirically live (reading the same file 3x produced zero blocks) before the fix. Every other hook in this repo reads stdin JSON instead (bug-278) — that's the reliable pattern; treat any argv/env-var-based hook wiring as suspect until verified.

## Decision Log (condensed)

- Symlinked (not copied) superpowers skills into `~/.claude/skills/` for auto-updates.
- Absorbed skill-development into writing-skills rather than installing both.
- Wired senior-engineering-partner as a **reference library only**; added Project Tier (0/1/2) table to CLAUDE.md for maturity-scaled rigor.
- Wired lint/secret-scan gate as a tracked local `.githooks/pre-commit` — Tier 0, survives cloning, warn-and-skip on missing tools.
- Added `github-issue-first` and `issue-backlog-cycle` as dedicated global skill files.
- Escalated `grilling` to a hard `PreToolUse`/`PostToolUse` hook pair blocking `writing-plans` without it.
- Installed all 13 `taste-skill` variants per explicit user request; mitigated conflict risk via a routing table in `claude-infra-reference`.
- Added `playwright` MCP server for session-driven browser automation over a committed E2E suite.
- Evaluated memU for cross-session memory/skill-extraction — declined: existing session-reflect → github-issue-first → writing-skills → PR pipeline covers it; built a narrower cross-session recurrence-detection addition instead (PR #51).
- Evaluated Caveman (github.com/JuliusBrussee/caveman, 8+ installable components) — declined the installer entirely (BSL-1.1 binaries, telemetry-on-by-default, mostly duplicates `context-tools`/OpenWolf/Playwright already in place) and hand-authored just the one genuinely novel piece (token-density terseness) as a ~60-line bespoke hook instead. General pattern for future third-party tool asks: inventory every component + license before installing anything, cross-check each against existing tooling, and prefer re-implementing the one real gap over running an installer that brings unrelated footprint (PR #59, issue #56).
- 2026-08-19: Audited `repowise-dev/repowise` (AGPL-3.0 codebase-intelligence tool), extracted 8 reimplementable-lightweight patterns, decomposed into 4 independent groups: **A** hook hardening (re-read gate content-hash upgrade + wrong-path rescue hook), **B** Bash output distillation, **C** transcript-mined memory/decision-injection, **D** CLI health-check verbs (`doctor`/`saved`). Built and merged Group A only (issue #68, PR #69 + follow-up sync PR #70) — content-hash re-read gate, per-path retry override, SessionStart reset for the previously-unbounded `.wolf/_session.json`, and the anatomy.md-matched wrong-path rescue hook. **Groups B, C, D are still unstarted** — next repowise-audit session should brainstorm Group B (context-tools/`post-bash-truncate.js` overlap) first per the original recommended order.
