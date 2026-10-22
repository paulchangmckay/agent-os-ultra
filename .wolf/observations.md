# Skill Observation Log

Observations captured during task-oriented work. Separate from cerebrum.md
(daemon-owned) — this file is owned by session-reflect and
hooks/post-compact-observation.js / hooks/post-write-batch-nudge.js.

**Status key:** OPEN = not yet actioned | ACTIONED (YYYY-MM-DD) = applied |
DECLINED (YYYY-MM-DD) = reviewed, not pursued

---

### Observation 14: Correction to Observation 12: subagent-driven-development/executing-plans root cause confirmed (missing symlinks, not transient API flakiness)

**Status:** ACTIONED
**Date:** 2026-07-27
**Type:** skill-improvement
**Session:** 
**Skill:** subagent-driven-development
**Issue:** Observation 12 was DECLINED on 2026-07-25 with the theory that 'Unknown skill' failures for subagent-driven-development/executing-plans were transient API instability, not a real registration gap -- explicitly flagged as unverified ('do not treat as confirmed without reproducing in a stable session first'). This session reproduced it in a stable session with no API errors present, and found the actual root cause: unlike every other superpowers skill (all symlinked as skills/<name> -> ../superpowers/skills/<name>), subagent-driven-development, executing-plans, and finishing-a-development-branch had no symlink in ~/.claude/skills/ at all -- confirmed via ls -la across all superpowers-sourced skills.
**Suggested improvement:** Fixed durably this session: created the three missing symlinks (ln -s ../superpowers/skills/<name> <name> from ~/.claude/skills/). Note: the Skill tool's available-skills list is loaded once at session start -- the newly created symlinks were NOT picked up mid-session (still returned 'Unknown skill' immediately after creating them); they only became invokable after a session restart. So within an already-running session that hits this, the correct move is still the documented workaround (read the skill file directly, follow its instructions manually) -- the symlink fix pays off for the *next* session, not the current one.
**Principle:** When a skill/tool intermittently or consistently fails as 'unknown', check for a structural registration gap (e.g. compare its presence against sibling skills from the same source) before attributing it to transient infrastructure noise -- a plausible-sounding 'probably flaky API' explanation can mask a real, permanent, cheaply-fixable gap.

### Observation 32: Grilling caught 5 real gaps in check-upstream spec via mechanical verification

**Status:** DECLINED (2026-10-22) — Confirms an existing fix (grilling's mechanical-verification instruction, skills/grilling/SKILL.md line 12) is working as intended on a new spec type (config/workflow vs. pure code/data) -- not a new gap, nothing to act on.
**Date:** 2026-10-07
**Type:** write-batch-checkpoint
**Session:** 
**Skill:** grilling
**Issue:** First-pass brainstorming design for check-upstream looked complete but missed: local-customizations branch going stale on submodule apply, per-plugin mirror clones duplicating shared repos (claude-plugins-official backs 5 plugins from 1 repo), a TOCTOU window in claude plugin update, mirror-clone gitignore treatment, and how to bootstrap last_reviewed_sha with no reliable installed-commit signal.
**Suggested improvement:** All 5 were found by running real commands (git log/branch on langsmith-plugin, reading known_marketplaces.json and .gitignore) rather than reasoning from the spec text alone, confirming grilling's 'verify mechanically before arguing' instruction earns its keep on config/workflow specs, not just code specs.
**Principle:** 
**Evidence:** Recurs: Observations #6/#10/#18 (log-2026-08-10.md) and #21 (log-2026-08-19.md), all ACTIONED 2026-08-10, fix confirmed still present in grilling/SKILL.md

### Observation 33: Plan self-review checklist does not catch execution-level bugs in the plans own provided code

**Status:** ACTIONED (2026-10-22) — Added Self-Review check 5 (Non-happy-path trace) to skills/writing-plans/SKILL.md for the genuinely-new half (self-review never traced plan-provided code logic). The other half (final review catches what task review misses) is already covered by Observation 19's fix and is folded into Observation 35's escalated issue, since it recurred there too.
**Date:** 2026-10-07
**Type:** skill-improvement
**Session:** unknown
**Skill:** writing-plans
**Issue:** During subagent-driven-development execution of the 2026-09-23 model-routing plan (issue #86, PR #98), two separate task reviews (Task 3, Task 4) found real bugs that originated in the plans own bash/JS code snippets, not in anything the implementer introduced: (1) race subshells missing an || true guard under set -e, silently mis-selecting the race winner on a transient curl failure; (2) inconsistent usage-field shape between two code paths, one reshaping down to two fields, the other passing the object through unmodified. Both were plan-mandated (present verbatim in the brief), meaning writing-plans own Self-Review pass (placeholder scan, internal consistency, type consistency, pattern verification) did not surface them, since neither is a placeholder or a naming mismatch -- theyre executable-logic defects that only show up when someone actually traces the code path or runs it. The final whole-branch review (and two re-reviews) subsequently caught several more of this class: a stale diagnostic file logged as a fresh success, missing .gitignore entries for new runtime logs, an omitted-parameter bypass of a safety gate, and an escape hatch around the features own core guarantee -- none of these were caught by any task-scoped review either, only by the broader whole-branch pass.
**Suggested improvement:** For a plan task whose deliverable is nontrivial executable logic (not just config/text), writing-plans Self-Review should include a step that actually traces or mentally executes each nonhappy-path branch the code defines (error paths, concurrent/backgrounded operations, cross-path consistency of shared data shapes, optional-parameter omission) rather than only checking the plan documents internal textual consistency. This does not replace task review or the final whole-branch review -- it is a cheaper earlier catch, before a reviewer subagent has to find the same class of bug after real implementation work already happened. Separately: this session confirmed subagent-driven-development final whole-branch review is NOT a formality -- across one branch it found 6 Important findings across 3 review rounds that zero task-scoped reviews caught, reinforcing the existing cross-cutting principle from Observation 19.
**Principle:** 
**Evidence:** Half A recurs: Observation 19 (ACTIONED 2026-08-19, cross-cutting-principles.md) -- see Observation 35 for the escalation this triggered

### Observation 34: Shell-embedded skill instructions: pathspec, pipe, and exit-code traps invisible without live verification

**Status:** ACTIONED (2026-10-22) — Added as a new Active Principle in .wolf/cross-cutting-principles.md (shell-embedded-command edge-case verification) rather than editing bloat-audit's own SKILL.md, since the lesson generalizes to any skill authoring shell-embedded instructions, not bloat-audit's runtime behavior specifically.
**Date:** 2026-10-08
**Type:** skill-improvement
**Session:** 026ca0ad-49e3-48c5-87d6-c1a1ddb3acd5
**Skill:** bloat-audit
**Issue:** Shell commands embedded in skill instructions had three separate exit-code or escaping traps found only via live verification, not by reading the prose: (1) a reset-style command with an empty pathspec variable can reset far more than intended, not act as a no-op; (2) backslash-escaped pipes used to satisfy markdown table syntax get copied verbatim by an agent reading raw file text, turning a real pipe into a literal character; (3) piping a command into sed or grep for text extraction makes the pipeline exit status reflect the downstream command, not the upstream one, silently swallowing a failure a Failure-handling rule depended on.
**Suggested improvement:** When a skill instructs running shell commands with variable-pathspec args, pipe-based extraction, or markdown-table-embedded pipes, verify each by actually running it against the real edge case (empty-list, no-match, verbatim-copy) before trusting the prose -- these three failure modes were each independently invisible on inspection and only surfaced when a reviewer or controller ran the literal command.
**Principle:** 

### Observation 35: Per-task reviews with synthetic fixtures miss real-data integration bugs that only a final whole-branch review catches

**Status:** ACTIONED (2026-10-22) — Escalated per the Substantial rule -- matches Observation 19's already-ACTIONED fix (cross-cutting-principles.md bullet) but recurred anyway, worse. Filed GitHub issue #106 tracking a structural fix (real-artifact integration testing at task-review time, not only at the final whole-branch review); needs its own brainstorming/planning pass before implementation.
**Date:** 2026-10-09
**Type:** cross-cutting-principle
**Session:** 
**Skill:** subagent-driven-development
**Issue:** All 7 per-task reviews of check-upstream passed clean using synthetic tmpdir git fixtures. The final whole-branch review ran the code against the REAL committed registry/mirrors and found 2 Critical + 4 Important bugs none of the per-task reviews caught: a ~-prefixed path that execFileSync never expands, an unscoped commit that could sweep in unrelated staged changes, an ancestry check that ran after a mutation instead of before, and an uninitialized-submodule path-resolution bug. A second fix round then reintroduced one of the Critical bugs via new prose in a different code path, caught only by re-running the real integration test again.
**Suggested improvement:** When a plan's tasks each test against synthetic fixtures (tmpdir repos, fabricated registries), explicitly require at least one integration test against the REAL on-disk artifacts (the actual committed config/registry file, actual real paths) before the final whole-branch review, not only at that review. Cheaper to catch at task-review time than to discover 7 tasks deep. Also: after any fix pass that touches multiple code paths doing the same thing (e.g. submodule vs marketplace commit scoping), explicitly re-check that the fix was applied symmetrically everywhere the same pattern appears, not just the path the original finding named.
**Principle:** 
**Evidence:** Recurs: Observation 19 (ACTIONED 2026-08-19, cross-cutting-principles.md 'Never skip the final whole-branch review as a formality'), Observation 33 (same review, related plan-authoring-time gap)
