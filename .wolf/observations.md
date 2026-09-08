# Skill Observation Log

Observations captured during task-oriented work. Separate from cerebrum.md
(daemon-owned) — this file is owned by session-reflect and
hooks/post-compact-observation.js / hooks/post-write-batch-nudge.js.

**Status key:** OPEN = not yet actioned | ACTIONED (YYYY-MM-DD) = applied |
DECLINED (YYYY-MM-DD) = reviewed, not pursued

---

### Observation 3: Exploration conflated a local directory 0-commit state with an unverified remote GitHub repo

**Status:** ACTIONED (2026-08-10) — Added external-resource verification + auto-generating-pipeline/deploy-target check to brainstorming SKILL.md Checklist item 1
**Date:** 2026-07-21
**Type:** skill-improvement
**Session:** 4441f778-7b4e-49d8-90f4-72cbfd6ef671
**Skill:** brainstorming
**Issue:** During brainstorming for the GitHub-first ~/.claude workflow spec, exploration confirmed the local ~/brain directory had 0 commits and separately ran `gh repo view` on the target remote (paulchangmckay/brain) which returned metadata with no commit count. The design doc then stated the remote was "empty, 0 commits" without ever running a query that actually returns remote commit count/tree (e.g. `gh api repos/OWNER/REPO/commits`). The claim went into an approved spec and a plan (Task 4: push to "empty" remote), and only surfaced as wrong when the implementer subagent hit a real push conflict — the remote in fact had 3 pre-existing commits and required a mid-execution force-push decision from the user.
**Suggested improvement:** When a brainstorming/design spec makes a factual claim about the state of an external system (a GitHub repo, a remote service, a deployed resource) that a later step will act on destructively or irreversibly (push, overwrite, delete), the exploration step should be required to verify that exact claim with a command whose output demonstrates it (not infer it from a related-but-different resource, and not from the absence of a field in unrelated metadata). Consider adding this as an explicit checklist item in brainstorming's project-context-exploration step: "for any external/remote resource the plan will act on destructively, confirm its actual current state with a direct query — do not infer from a similarly-named or adjacent resource."
**Principle:** Verify the exact resource and exact property the plan depends on, with a command that demonstrates it directly — proximity or naming similarity to something already verified is not evidence.

### Observation 4: No lightweight tier for small CLAUDE.md / rules-file additions

**Status:** ACTIONED (2026-08-10) — Already fixed independently: CLAUDE.md brainstorming HARD-GATE row now has an explicit exempt clause for small additive doc/rules-file changes
**Date:** 2026-07-22
**Type:** skill-improvement
**Session:** 
**Skill:** brainstorming / github-issue-first / using-git-worktrees
**Issue:** Added .claude/rules/portable-repo.md and a one-line CLAUDE.md reference directly on main, with no worktree, no github-issue-first, no brainstorming/grilling/writing-plans pass — technically a violation of CLAUDE.md §2's HARD-GATE table ("Before any feature work or new task → brainstorming"), which has no carve-out for small, additive, easily-revertible documentation/rules changes. Justified in the moment by proportionality (2-file doc diff, git-tracked, not pushed) and by an existing precedent — §3's observations.md already has a two-tier rule ("small additive changes → inline diff, approved, written live; substantial changes → github-issue-first → worktree → PR") — but that precedent is scoped only to observations.md, not to CLAUDE.md itself or new files under .claude/rules/.
**Suggested improvement:** Either (a) extend the existing observations.md two-tier precedent explicitly to CLAUDE.md/.claude/rules/*.md edits in §2 or §3, so small additive doc changes have a sanctioned fast path instead of relying on ad-hoc judgment call each time, or (b) make the HARD-GATE table explicitly apply only to code/behavior changes and state that pure documentation/rules additions are exempt, matching how the brand skill already carves out an explicit exemption for /teach lesson output in the same table row.
**Principle:** A HARD-GATE with zero exceptions gets silently judgment-called around for genuinely small changes rather than actually followed — better to name the fast path explicitly (as already done once for observations.md) than to leave every future small-doc-change decision to be re-litigated informally each time.

### Observation 5: skill-improvement: brainstorming

**Status:** ACTIONED (2026-08-10) — Added publish-target/auto-generating-pipeline check to brainstorming SKILL.md Checklist item 1 (same fix as Observation 3)
**Date:** 2026-07-23
**Type:** skill-improvement
**Session:** 2cbcdfb5-28f6-4600-9889-b08dafc8a9bc
**Skill:** brainstorming
**Issue:** Initial design pass for publishing docs-site missed two concrete technical gaps that only surfaced during the mandatory grilling pass: (1) generated Astro config hardcoded a localhost site URL with no base path, which would 404 all links once deployed to a GitHub Pages project subpath; (2) the auto-generating content sync script walks all .md files in a skill directory with no exemption, so a personal/operational reference file (my-environment.md) was being swept into public content unnoticed.
**Suggested improvement:** When a design goal includes publishing/exposing something publicly, brainstorming exploration should explicitly check (a) any auto-generating/walking pipeline for content it might sweep in unintentionally, and (b) target-deploy defaults baked into generated framework configs (base paths, site URLs) against the actual deploy target -- not leave these for grilling to catch.
**Principle:** 

### Observation 6: Live-verification grilling caught 5 real bugs a conversation-only pass would have missed

**Status:** ACTIONED (2026-08-10) — Added mechanical-verification-over-metadata guidance to grilling SKILL.md, covering data-pipeline/ETL live-verification
**Date:** 2026-07-23
**Type:** skill-improvement
**Session:** 2590831d-091e-424c-9666-bb40ab15351d
**Skill:** grilling
**Issue:** During a grilling pass on an NHL advanced-analytics spec (secondary project), following the skill instruction to explore the codebase instead of just asking the user surfaced concrete, verifiable defects: (1) regular-season OT is 5min not 20min, breaking a flat period-offset assumption; (2) shootout periods carry non-strength situationCode values that would have contaminated the sweep; (3) goalies have player_shifts rows and would have been silently credited Corsi/Fenwick like skaters; (4) a proposed 5-bucket strength_state enum missed real states (5-on-3, both-goalies-pulled) visible in a single sample game; (5) the NHL API field needed for rink-side-correct HDSC (homeTeamDefendingSide) was never captured during the original ingestion backfill, only discoverable via a live curl against the raw API, not by reading the existing schema/code.
**Suggested improvement:** Grilling sessions on data-pipeline / ETL specs should default to live-verifying assumptions (curl the real API, query the actual local DB for enum/cardinality checks) rather than reasoning from the spec author's written description of the data shape, whenever the spec makes claims about an external API's field structure or a fixed/small enum derived from real-world data. Generic domain knowledge (e.g. "NHL periods are 20 minutes") was wrong in a way that only showed up by checking OT specifically.
**Principle:** 

### Observation 7: Plan assumed sibling tables share one convention; player_career_stats actually differs from player_season_stats

**Status:** ACTIONED (2026-08-10) — Added Self-Review check 4 (Pattern verification) to writing-plans SKILL.md
**Date:** 2026-07-24
**Type:** skill-improvement
**Session:** 2590831d-091e-424c-9666-bb40ab15351d
**Skill:** writing-plans
**Issue:** The advanced-analytics implementation plan (NHL Stats project) assumed player_career_advanced_stats should mirror player_season_advanced_stats's game_type-column convention, by analogy with the season table. Reading src/database.py during Task 4 implementation showed player_career_stats actually uses a totally different convention: rs_/po_ (regular season/playoffs) column prefixes on one row per player, not a game_type row split. The plan document never verified this against the real schema, just assumed sibling tables (game/season/career triads) share one shape.
**Suggested improvement:** When a plan proposes a new table explicitly modeled on an existing one ("mirror the existing X pattern"), writing-plans should read the actual CREATE TABLE statement for every table in that lineage (not just the nearest one) before committing to a column shape in the plan doc, since sibling tables in the same aggregation chain (game -> season -> career) can each have evolved their own convention independently.
**Principle:** 

### Observation 8: Fully-green test suite missed two Critical bugs: fabricated test fields + unwired functions

**Status:** ACTIONED (2026-08-10) — Added Anti-Pattern 6 (Fabricated Fixture Fields & Unwired Functions) to testing-anti-patterns.md, plus Quick Reference/Red Flags rows
**Date:** 2026-07-25
**Type:** skill-improvement
**Session:** 2590831d-091e-424c-9666-bb40ab15351d
**Skill:** test-driven-development
**Issue:** During the NHL advanced-analytics implementation, a code-review subagent (requesting-code-review) caught two Critical bugs that 79 passing backend tests never surfaced: (1) etl/advanced_stats/sweep.py depended on a period_type field for shootout exclusion, but test_sweep.py fabricated that field directly in its fixture dicts (_shift/_event helpers) rather than ever exercising the real DB-row-to-dict path (_load_shifts_for_sweep/_load_events_for_sweep in compute_advanced_stats.py), which never selected any such column -- because no such column exists anywhere in the schema. The default fallback (.get("period_type", "REG")) silently always won in production, so shootout attempts were never actually excluded. (2) compute_season_aggregates and compute_percentiles were written with their own passing direct-call unit tests, but nothing in run(), run_all_etl.py, or the documented CLI commands ever actually invoked them -- confirmed via grep showing zero non-test callers. Both slipped through TDD discipline because each function/module was tested in isolation and passed, but the tests never validated the seam between layers (real extracted-row shape, and real production wiring).
**Suggested improvement:** For ETL/pipeline-style code with a DB-row -> transform -> output chain, add at least one true end-to-end test per feature that exercises the full real path (seed DB rows in the actual schema -> call the real top-level entrypoint like run() -> assert on final output tables), in addition to (not instead of) fast isolated unit tests with synthetic fixtures. Isolated-unit-test fixtures that include fields not actually produced anywhere in the real extraction path are a red flag during self-review -- grep for the field name outside the test file before trusting the test. Also, after writing any new function meant to run automatically in production, grep for its call sites before considering the task done; a function with a passing unit test but zero non-test callers is exactly the shape of this bug.
**Principle:** 

### Observation 9: skill-improvement: brainstorming

**Status:** ACTIONED (2026-08-10) — Added Claude-authors-content-directly question to brainstorming SKILL.md Checklist item 3
**Date:** 2026-07-25
**Type:** skill-improvement
**Session:** gmat-project-brainstorm
**Skill:** brainstorming
**Issue:** During a brainstorming design pass, proposed a standalone dev-time script that calls the Claude API (with its own API key/billing) to generate content, without considering that Claude Code itself is already the authoring agent in the session. User caught it by asking why an API key was needed at all.
**Suggested improvement:** When a design calls for "AI-generated content" and the work is happening inside a Claude Code session, default to Claude authoring the content directly during implementation (no separate API-calling script/key) unless there is a stated need for the generation to run outside a Claude Code session (e.g. a cron job, or reuse by someone without Claude Code). Brainstorming should ask about this explicitly before designing a content-generation pipeline.
**Principle:** 

### Observation 10: grilling verified dependency metadata but not the actual install command

**Status:** ACTIONED (2026-08-10) — Folded into grilling SKILL.md's mechanical-verification addition (same fix as Observation 6/18)
**Date:** 2026-07-25
**Type:** skill-improvement
**Session:** 91b86850-fb8e-4a53-b528-1b0584335b22
**Skill:** grilling
**Issue:** During grilling on the markitdown-skill spec, I checked PyPI requires_dist metadata to disprove a suspected torch/Python-3.14 install risk, concluded the python3.11 pipx fallback was unnecessary speculative insurance, and the user agreed to drop it. Actually running `pipx install 'markitdown[all]'` afterward (during writing-plans, not grilling) revealed a different, real Python-3.14 problem the metadata read missed: pip silently backtracks to a crippled markitdown==0.0.2 because xlrd and youtube-transcript-api~=1.0.0 have no 3.14-compatible releases -- with no error, just a wrong version silently installed. Reading requires_dist confirmed what a package depends on but not whether pip can actually resolve those pins on this Python version.
**Suggested improvement:** When grilling or spec-writing resolves a technical risk question by reading package metadata (PyPI JSON, requirements files, changelogs) rather than by actually running the install/command, treat that as a hypothesis, not a verified fact -- flag it in the spec as "metadata-verified, not install-verified" and re-check once the real command is run (even ephemeral via `pipx run`/`npx`/similar) before treating the simplification as final. This is a step beyond typical grilling scope -- worth surfacing as a specific case of the general verify-before-asserting discipline.
**Principle:** 

### Observation 11: document-skills:pdf description does not reciprocally disclaim into markitdown

**Status:** DECLINED (2026-08-10) — document-skills:pdf is a vendored marketplace plugin, not owned by this repo -- fix would need to happen upstream, deferring until it's next touched
**Date:** 2026-07-25
**Type:** skill-improvement
**Session:** 91b86850-fb8e-4a53-b528-1b0584335b22
**Skill:** document-skills:pdf
**Issue:** While verifying the new markitdown skill's disambiguation from document-skills:pdf/docx/pptx/xlsx (issue #21), both Task 3's verification and the final whole-branch review independently noticed an asymmetry: markitdown's description explicitly disclaims edit/create/form-fill intent ("not for creating, editing, or filling forms in documents -- use document-skills:... for that"), but document-skills:pdf's description has no reciprocal disclaimer -- its broad closing clause ("If the user mentions a .pdf file... use this skill") plus "reading or extracting text/tables from PDFs" as its first listed operation could plausibly also fire on a plain read-only "summarize this PDF" request, alongside or instead of markitdown.
**Suggested improvement:** When document-skills:pdf (a marketplace-vendored plugin, not owned by this repo) next gets touched/updated, consider adding a reciprocal disclaimer to its description -- something like "for read-only extraction/summarization without editing, prefer the markitdown skill instead" -- so the two skills' routing logic is symmetric rather than markitdown being the only one that yields ground.
**Principle:** 

### Observation 14: Correction to Observation 12: subagent-driven-development/executing-plans root cause confirmed (missing symlinks, not transient API flakiness)

**Status:** ACTIONED
**Date:** 2026-07-27
**Type:** skill-improvement
**Session:** 
**Skill:** subagent-driven-development
**Issue:** Observation 12 was DECLINED on 2026-07-25 with the theory that 'Unknown skill' failures for subagent-driven-development/executing-plans were transient API instability, not a real registration gap -- explicitly flagged as unverified ('do not treat as confirmed without reproducing in a stable session first'). This session reproduced it in a stable session with no API errors present, and found the actual root cause: unlike every other superpowers skill (all symlinked as skills/<name> -> ../superpowers/skills/<name>), subagent-driven-development, executing-plans, and finishing-a-development-branch had no symlink in ~/.claude/skills/ at all -- confirmed via ls -la across all superpowers-sourced skills.
**Suggested improvement:** Fixed durably this session: created the three missing symlinks (ln -s ../superpowers/skills/<name> <name> from ~/.claude/skills/). Note: the Skill tool's available-skills list is loaded once at session start -- the newly created symlinks were NOT picked up mid-session (still returned 'Unknown skill' immediately after creating them); they only became invokable after a session restart. So within an already-running session that hits this, the correct move is still the documented workaround (read the skill file directly, follow its instructions manually) -- the symlink fix pays off for the *next* session, not the current one.
**Principle:** When a skill/tool intermittently or consistently fails as 'unknown', check for a structural registration gap (e.g. compare its presence against sibling skills from the same source) before attributing it to transient infrastructure noise -- a plausible-sounding 'probably flaky API' explanation can mask a real, permanent, cheaply-fixable gap.

### Observation 15: compaction-checkpoint: session

**Status:** DECLINED (2026-08-10) — Stale compaction-checkpoint from 2026-07-27 with no specific content and no matching session activity found; nothing to enrich
**Date:** 2026-07-27
**Type:** compaction-checkpoint
**Session:** ec68827a-09b3-4c8b-9676-b22118548168
**Skill:** session
**Issue:** Compaction occurred; context may contain unlogged insights.
**Suggested improvement:** Review this session's work and either enrich this entry or resolve DECLINED if nothing generalizes.
**Principle:** 

### Observation 16: New skill candidate: ephemeral SDK/API verification before writing exact code into a spec or plan

**Status:** ACTIONED (2026-08-10) — Already built: GitHub issue #34, design spec, and SKILL.md exist for verify-sdk-api in worktree feature+34-verify-sdk-api-skill
**Date:** 2026-07-27
**Type:** new-skill-candidate
**Session:** 
**Skill:** verify-sdk-api (working name)
**Issue:** This session repeatedly needed to verify real third-party SDK behavior (the Pinecone Python client) before committing exact code into a spec/plan/implementation: exception class hierarchy and attributes (NotFoundException, PineconeApiException.status_code), current-vs-deprecated API surface (pc.indexes.create with IntegratedSpec/EmbedConfig vs the deprecated create_index_for_model), and a genuine upstream packaging bug (pinecone==9.1.0 imports typing_extensions at runtime but never declares it in its own wheel metadata). Each check followed the same ad-hoc pattern: create a throwaway venv, pip install the exact pinned version, introspect via inspect.signature/inspect.getdoc or by grepping the dist-info METADATA, then discard the venv. No existing skill packages this workflow -- it was reinvented from scratch each time.
**Suggested improvement:** A lightweight skill that: (1) spins up an ephemeral install (venv for Python, a scratch npm install for JS) of a pinned package version, (2) introspects the actual installed signatures/exception hierarchy/declared-dependency metadata for whatever symbols a task needs, (3) tears down the ephemeral environment, (4) hands back verified facts to fold into a spec, plan, or implementation. Should generalize beyond Python/Pinecone -- the same need arises for any SDK whose docs or training-data knowledge might be stale or version-specific.
**Principle:** Documentation and model training-data knowledge of a library's API can be stale, wrong, or version-specific. A live ephemeral install-and-introspect is cheap insurance before committing exact code into a plan, and directly supports the deterministic-first, verify-before-asserting discipline this environment already values elsewhere.

### Observation 18: Source-reading during grilling isn't sufficient for third-party installer side effects — verify the actual post-run diff

**Status:** ACTIONED (2026-08-10) — Folded into grilling SKILL.md's mechanical-verification addition (same fix as Observation 6/10)
**Date:** 2026-07-28
**Type:** skill-improvement
**Session:** context-mode MCP integration, Task 1 execution
**Skill:** grilling
**Issue:** 
**Suggested improvement:** During the context-mode MCP integration (docs/superpowers/specs/2026-07-27-context-mode-integration-design.md), grilling correctly predicted one settings.json side effect by reading start.mjs's source (a SessionStart cache-heal hook). Running the real install produced a second, unpredicted side effect (an enabledPlugins flag) that source-reading alone missed. For any design/grilling pass covering a third-party installer or self-heal/auto-registration script, add an explicit step: after the real command runs, diff the actual config file it touches rather than relying solely on source-reading predictions.
**Principle:** 

### Observation 19: Final whole-branch review catches cross-cutting bugs task reviews structurally cannot

**Status:** ACTIONED (2026-08-19) — Added principle to .wolf/cross-cutting-principles.md
**Date:** 2026-08-10
**Type:** cross-cutting-principle
**Session:** 
**Skill:** subagent-driven-development
**Issue:** On the verify-sdk-api branch (issue #34), all 5 per-task reviews approved cleanly, but the final whole-branch review (opus, scoped to the full branch diff) found 2 Critical + 3 Important issues none of the task reviewers caught.
**Suggested improvement:** (1) verify-js.sh inspect died under set -euo pipefail on any .d.ts grep miss -- invisible to the Task 4 reviewer because the only test package (lodash) ships no .d.ts at all, so that code path was never exercised. (2) SKILL.md documented relative scripts/... paths that only resolve from the repo root -- invisible to the Task 5 GREEN subagent because it happened to run with cwd already at the repo root, the one place the bug does not manifest. Both required either a different test fixture (a typed npm package) or a different invocation context (cwd outside the repo) to surface -- exactly what a task-scoped reviewer, working from one commits diff, has no reason to try. Principle: the two-tier gate worked as designed -- task reviews catch spec/quality issues per-commit, the final whole-branch review catches integration-level and real-world-usage issues that only exist across the whole branch. Never skip the final review as a formality even when every task review was clean.
**Principle:** 
**Evidence:** cross-cutting-principles.md Active Principles, bullet 1

### Observation 20: Add a git merge driver for append-only .wolf/* logs

**Status:** ACTIONED (2026-08-19) — Filed as GitHub issue #66 for worktree pickup
**Date:** 2026-08-14
**Type:** skill-improvement
**Session:** 0dcd66bf-f697-4bde-97f4-cbaaa66990f8
**Skill:** using-git-worktrees
**Issue:** Pushing routine .wolf/anatomy.md, buglog.json, memory.md changes to main hit hand-resolved merge conflicts across 5+ cycles in a single session, because concurrent sessions/daemon hooks keep appending to the same files between fetch and push. anatomy.md/cerebrum.md are wholesale-regenerated (take-newest-plus-rescan, already documented in CLAUDE.md), but memory.md (append-only session log) and buglog.json (auto-incrementing ID array) required hand-splicing conflict markers back together each time, including manually renumbering colliding buglog IDs from uncoordinated concurrent sessions.
**Suggested improvement:** Add a git merge driver (.gitattributes + a small script) for these specific .wolf/*.md/json files: union/concat-in-order for memory.md's session blocks, and a concat-plus-ID-renumber step for buglog.json's array. Would make `git pull`/`git merge` resolve these automatically instead of requiring manual conflict resolution every time routine log commits race a push.
**Principle:** 
**Evidence:** https://github.com/paulchangmckay/brain/issues/66

### Observation 21: cross-cutting-principle: grilling, writing-plans

**Status:** ACTIONED (2026-08-19) — Added principle to .wolf/cross-cutting-principles.md
**Date:** 2026-08-15
**Type:** cross-cutting-principle
**Session:** 
**Skill:** grilling, writing-plans
**Issue:** The grilled and approved cross-session-recurring-pattern-detection spec specified adding an evidence field to wolf-observation-log.js's append command. During writing-plans, mapping the spec to actual code revealed append never fires in the Phase 3 flow that needed evidence — Phase 3 only scans and resolves already-existing OPEN entries, it never creates new ones. The correct attach point was resolve, not append. Grilling asked hard questions about decision branches (escalation rules, routing criteria, corpus bounds) but did not verify that the proposed schema change actually attaches at a point the described data flow exercises.
**Suggested improvement:** When grilling a spec that names a specific function/operation as the change point for a schema/data addition, add one verification question: walk the actual call sequence the spec describes and confirm the named operation is the one that fires at that point in the flow. Mechanical verification, not just architectural soundness.
**Principle:** A schema change can be self-consistent and grilled thoroughly while still attaching to the wrong operation if nobody re-traces the literal call sequence the design assumes.
**Evidence:** cross-cutting-principles.md Active Principles, bullet 2

### Observation 22: skill-improvement: using-git-worktrees

**Status:** ACTIONED (2026-08-19) — Filed as GitHub issue #67 for worktree pickup
**Date:** 2026-08-15
**Type:** skill-improvement
**Session:** 
**Skill:** using-git-worktrees
**Issue:** Resolving a .wolf/buglog.json merge conflict required hand-rolling a one-off node script (require both git stages as JSON, dedup by timestamp+error_message+file content-key, verify one side is a strict superset) because no documented procedure or reusable script exists for ID-numbered append-only logs specifically — the existing cerebrum.md guidance only covers plain concatenation (memory.md) and --ours+rescan (anatomy.md), neither of which fits an ID-collision case. Happened twice in one session (once merging the feature branch into origin/main, once syncing local main afterward).
**Suggested improvement:** Add a small reusable script (e.g. scripts/resolve-numbered-log-conflict.js) that takes two git-stage refs for a JSON array-of-objects file, a content-key field list, and dedupes/verifies supersets automatically — or at minimum, document the git-stage-extraction + content-key-dedup technique as a named step in using-git-worktrees or the cerebrum Git/Worktree pattern, so it is followed by procedure next time instead of re-derived under time pressure.
**Principle:** Auto-numbered append-only logs (sequential IDs assigned by a project-wide hook, not scoped to the checked-out branch) collide differently than plain append-only logs — the general worktree-merge guidance silently does not cover this case, and that gap was only caught because the resulting JSON was manually diffed rather than trusted.
**Evidence:** https://github.com/paulchangmckay/brain/issues/67

### Observation 23: Custom-agent section omits the plugin-based registration mechanism

**Status:** ACTIONED (2026-08-19) — Added plugin-based registration bullet to claude-infra-reference SKILL.md Custom Agents section
**Date:** 2026-08-16
**Type:** skill-improvement
**Session:** 02b134f4-07af-4750-9f71-f896e22ae90a
**Skill:** claude-infra-reference
**Issue:** claude-infra-reference documents two custom-agent conventions (heavy ~/.claude/Agents/<name>/, and agent-team-architect's project-local .claude/agents/*.md). It never mentions the third mechanism that actually makes ba-agent:ba dispatchable today: claude plugins init <name> --with agents, which scaffolds ~/.claude/skills/<name>/agents/*.md + .claude-plugin/plugin.json, auto-loaded as <name>@skills-dir. A brainstorming session drafted a spec assuming agent-team-architect was the right tool to scaffold a new in-repo dispatchable subagent; only a mechanical check of ba-agent's actual files on disk (not the doc prose) caught that agent-team-architect self-guards against targeting ~/.claude, and that the plugin-based route was the one already proven working.
**Suggested improvement:** Add a third row/bullet to claude-infra-reference's Custom Agents section documenting claude plugins init <name> --with agents as the mechanism for in-repo dispatchable subagents (skills/<name>/agents/<name>.md, git-tracked, auto-loads as <name>@skills-dir), distinct from both the heavy ~/.claude/Agents/ convention and agent-team-architect's project-local convention. Cross-reference ba-agent as the working example.
**Principle:** 
**Evidence:** skills/claude-infra-reference/SKILL.md

### Observation 24: No guidance for content-only (non-code) task verification steps

**Status:** ACTIONED (2026-08-19) — Added Content-Only Task Verification subsection to writing-plans SKILL.md
**Date:** 2026-08-16
**Type:** skill-improvement
**Session:** 02b134f4-07af-4750-9f71-f896e22ae90a
**Skill:** writing-plans
**Issue:** writing-plans's Task Structure template and examples are entirely code/pytest-oriented ("Write the failing test", "Run test to verify it fails", "Write minimal implementation"). When a plan's deliverables are markdown skill files (no executable code, e.g. this session's two plans adding 6 new SKILL.md-based skills plus a subagent definition), the literal red-green TDD cycle doesn't apply, but the skill gives no guidance on how to adapt "testable deliverable" and "No Placeholders" to that case. Had to improvise: grep-based placeholder scans, wc -w word-budget checks, frontmatter-shape spot checks via head, in place of pytest run/expected-output steps.
**Suggested improvement:** Add a short subsection to writing-plans (or a references/ file) covering content-only task verification patterns: placeholder/forbidden-pattern grep checks, word/line budget checks via wc, frontmatter-shape spot checks, and a note that these substitute for the red-green cycle when a task's deliverable is markdown/config rather than executable code. Keeps the "No Placeholders" and "testable deliverable" principles intact without forcing an artificial test-first ritual onto content authoring.
**Principle:** 
**Evidence:** superpowers/skills/writing-plans/SKILL.md, before Remember section

### Observation 25: understand-anything gotchas found during worktree-based graph regen

**Status:** ACTIONED (2026-08-19) — Vendored plugin (understand-anything), can't edit skill directly -- added operational gotchas to cerebrum.md Process/Tooling instead
**Date:** 2026-08-17
**Type:** skill-improvement
**Session:** bloat-cleanup-bucket-a
**Skill:** understand-anything:understand
**Issue:** Three non-obvious traps hit while regenerating the knowledge graph inside a git worktree for a PR-based cleanup: (1) the skill defaults to redirecting all output to the main checkout when PROJECT_ROOT is a worktree, silently bypassing branch isolation unless UNDERSTAND_NO_WORKTREE_REDIRECT=1 is set. (2) merge-batch-graphs.py only accepts batch-N.json or batch-N-part-K.json filenames via regex -- naming the pruned-old-graph file batch-existing.json silently dropped 197 nodes and 361 edges with no error. (3) an incremental update only re-analyzes files already listed in the cached intermediate/scan-result.json inventory -- if that inventory is stale, files added to the repo since are silently never analyzed even though the run reports success with 0 validation issues.
**Suggested improvement:** Always pass UNDERSTAND_NO_WORKTREE_REDIRECT=1 (prefixed on every bash call, since env does not persist across tool calls) when regenerating the graph inside a worktree that will land via PR. When constructing a merged-old-graph batch file by hand, name it batch-N.json (a numeric placeholder like batch-9000.json works), never batch-existing.json. Before trusting an incremental run as complete, compare scan-result.json age and file count against the live repo file count -- if the repo has grown since that scan, force a full rebuild or re-run Phase 1 SCAN instead of trusting the incremental path.
**Principle:** 
**Evidence:** .wolf/cerebrum.md Process/Tooling section

### Observation 26: Partial verification of an inherited audit claim still needs re-checking every sub-detail

**Status:** ACTIONED (2026-08-19) — Added principle to .wolf/cross-cutting-principles.md
**Date:** 2026-08-18
**Type:** cross-cutting-principle
**Session:** bloat-cleanup-bucket-b
**Skill:** grilling
**Issue:** During the Bucket B design, I re-verified the headline claim from an earlier bloat-audit subagent (that design-taste-frontend and redesign-existing-projects share duplicated anti-slop content) by confirming a few concrete examples matched verbatim (99.99%, Acme/Nexus/SmartFlow). That partial verification created false confidence in an unverified secondary detail from the same audit pass -- the claim that the overlap was concentrated in design-taste-frontend's Section 9 -- which I repeated in the spec and in conversation with the user without checking it myself. Grilling's mechanical-verification step caught it: the actual shared bullets are scattered across four separate subsections (3.E, 4.2, 4.4, 9.A-9.D), not contained in one. This is the same failure mode as an earlier mistake this session (trusting a subagent's 0-of-241 buglog claim about detectFixPattern() being dead code, which was wrong because the field name searched didn't match the actual schema).
**Suggested improvement:** When re-verifying an inherited claim (from a subagent, an earlier pass, or prior conversation turns), treat every discrete sub-claim as needing its own check, not just the headline conclusion. Confirming 3 of 5 specific examples match does not confirm the 4th detail (e.g. 'where' the content lives, 'how many' places, 'which mechanism' is responsible) -- that still needs its own direct read. This matters most exactly when the check feels already-satisfied by adjacent verification.
**Principle:** 
**Evidence:** cross-cutting-principles.md Active Principles, bullet 3

### Observation 27: A test's own assertion needs the same mechanical verification as any inherited claim -- third recurrence this session

**Status:** ACTIONED (2026-08-19) — Added principle to .wolf/cross-cutting-principles.md
**Date:** 2026-08-19
**Type:** cross-cutting-principle
**Session:** bloat-cleanup-bucket-b
**Skill:** test-driven-development
**Issue:** Third instance of the same failure mode in one extended session: (1) trusted a subagent's buglog-field-name claim about detectFixPattern() being dead code without checking the actual schema -- it was live and heavily used; (2) trusted an inherited 'the overlap lives in Section 9' claim in a design spec without re-checking the 'where', only the 'what' -- it was scattered across 4 subsections; (3) wrote a plan's own test assertion (post-compact-anatomy.sh's backslash-escaping test) that was wrong on two counts -- the character it targeted (backslash) was already covered by the old code's allowlist, and the expected value itself (double backslash surviving JSON.parse) was objectively incorrect JSON round-trip behavior. All three only surfaced because a downstream step (grilling, an implementer's TDD RED run, or direct mechanical verification) happened to re-derive the same fact independently -- none were caught by re-reading the claim, only by re-deriving it.
**Suggested improvement:** Authoring a test assertion is itself a claim, not just a verification tool -- it needs the same 'run the real thing and read the output' discipline as any other inherited fact, especially for negative/absence assertions (proving old code was broken, proving a character was uncovered) which are easy to get backwards. Before writing an assertion that claims 'X was broken before, Y fixes it', actually run the 'before' case against real code and confirm the failure happens for the stated reason -- don't reason about it in the abstract. This applies with extra force to security- or correctness-adjacent code (JSON escaping, path sanitization, auth checks) where an inverted assertion silently proves nothing.
**Principle:** 
**Evidence:** cross-cutting-principles.md Active Principles, bullet 4

### Observation 28: new-skill-candidate: New skill candidate: external-skill-integration

**Status:** ACTIONED (2026-09-06) — Filed as GitHub issue #82 for worktree pickup
**Date:** 2026-08-30
**Type:** new-skill-candidate
**Session:** 
**Skill:** New skill candidate: external-skill-integration
**Issue:** Evaluating, installing, and documenting a third-party design/frontend skill (mattpocock, taste-skill, make-interfaces-feel-better, silk-design, now refero) has happened at least 5 times, each as an ad-hoc manual sequence: research the candidate repo, check for conflict with existing skills, pick the right install mechanism (npx skills CLI vs plugin marketplace vs vendored clone), then hand-write a routing-table row plus a detail section in claude-infra-reference/SKILL.md following the existing prose pattern. No skill wraps this workflow; each pass re-derives the same steps from scratch by reading the prior sections as examples.
**Suggested improvement:** A skill (or a checklist section inside claude-infra-reference itself) covering: how to evaluate a candidate skill/plugin repo for overlap with the existing taste-skill routing table, how to choose among the three install mechanisms seen so far (npx skills --global --copy, claude plugin marketplace add + install, vendored git clone with .git stripped), and a template for the routing-table row + detail-section writeup so the prose stays consistent across entries.
**Principle:** This is infra-maintenance work distinct from actual design/frontend work -- it recurs whenever a new external design skill is discovered, and the manual research-evaluate-install-document sequence is the same shape each time regardless of which skill is being integrated.
**Evidence:** https://github.com/paulchangmckay/agent-os-ultra/issues/82
