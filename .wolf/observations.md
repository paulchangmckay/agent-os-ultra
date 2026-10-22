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

### Observation 29: model-routing skill/CLAUDE.md never documented Fable, and a filled-in guess was materially wrong

**Status:** ACTIONED (2026-10-07) — Already fixed by a concurrent session before this review landed: skills/model-routing/SKILL.md Quick Reference now has a correct Fable row (escalation above Opus, pricing, official-docs citation, explicit note debunking the earlier wrong guess). No duplicate action needed.
**Date:** 2026-09-23
**Type:** skill-improvement
**Session:** unknown
**Skill:** model-routing
**Issue:** Neither skills/model-routing/SKILL.md nor CLAUDE.md section 3 mention the Fable model tier at all, despite it being a valid Agent tool model value. During a 2026-09-23 grilling pass, Claude guessed (from the name alone) that Fable was a creative-writing/narrative-voice model and drafted a routing rule around that. Web research against platform.claude.com/docs/en/models/fable-5-1/overview showed this was wrong: Fable 5.1 is actually the escalation tier ABOVE Opus 5.5 for demanding reasoning and long-horizon agentic work ($10/$50 per MTok vs Opus 5.5 $4/$20, default effort high), not a creative-writing model.
**Suggested improvement:** When a policy/routing skill needs to describe a model tier it has never documented, verify the tier's actual positioning against Anthropic's official platform docs before writing a routing rule around a name-based guess, even one explicitly flagged as low-confidence. Also confirmed: the Claude API has a real per-message effort parameter (beta), but it is not exposed on this harness's Agent tool today — worth tracking if that tool surface changes.
**Principle:** 
**Evidence:** Commits ddfdd2b (Grill model routing spec: fix Fable positioning) and 2ce8bad (Add model routing: local multi-backend dispatch and Claude-tier hard-block gate, #98)

### Observation 30: Check enabledPlugins before treating a marketplace plugin file as live

**Status:** ACTIONED (2026-10-07) — Added cross-cutting principle to .wolf/cross-cutting-principles.md: check enabledPlugins before building on a plugins/marketplaces/**/commands/*.md file, and check for CLI-builtin name shadowing.
**Date:** 2026-09-23
**Type:** cross-cutting-principle
**Session:** a3b57c23-9ecf-4fd7-97a5-62332f32f5f9
**Skill:** claude-infra-reference
**Issue:** Built a whole use-case (Jev confidence scoring for /code-review) on top of plugins/marketplaces/claude-plugins-official/plugins/code-review/commands/code-review.md before checking whether that plugin was actually enabled. It was not (missing from settings.json enabledPlugins), and separately a same-named native /code-review command is compiled into the CLI binary itself, unrelated to any file in the repo. The plugin file existing in plugins/marketplaces/ says nothing about whether it runs.
**Suggested improvement:** Before proposing changes to any plugins/marketplaces/**/commands/*.md file, grep settings.json enabledPlugins for that plugin key first. Also check whether the same command name is shadowed by a native CLI-builtin capability (visible in the Skill tool listing with no matching repo file) before assuming a plugin file is the thing that fires.
**Principle:** 

### Observation 31: skill-improvement: claude-infra-reference

**Status:** ACTIONED (2026-10-07) — Escalated per the escalation rule (fix already existed twice and still recurred) — filed as GitHub issue #100 rather than a third copy of the same prose reminder. Implementation deferred to a dedicated worktree session, not done in this session-reflect pass.
**Date:** 2026-10-07
**Type:** skill-improvement
**Session:** 
**Skill:** claude-infra-reference
**Issue:** npx skills@latest add <repo> <names...> --global --copy -y has now failed to filter by positional skill name on at least 2 separate occasions (taste-skill install warning already notes -s/--skill failing once) — this time it silently installed all 38 skills in mattpocock/skills and overwrote 6 already-installed skills, one of which had a local patch, requiring manual git-status diff and cleanup.
**Suggested improvement:** Either stop relying on the npx skills CLI for selective installs from this repo (clone + manually copy only the requested skill directories) or add a mandatory post-install git-status diff + revert step directly into the External Skill Integration Procedure checklist in claude-infra-reference, instead of leaving it as prose that is easy to skip under time pressure.
**Principle:** A documented workaround that still requires the operator to remember to verify after every single run is weaker than removing the unreliable step entirely; this is the 3rd confirmed failure of the same CLI behavior across 3 different integration sessions.
**Evidence:** Recurs: buglog bug-034 (1st occurrence, -s/--skill flag, ACTIONED fix), cerebrum Do-Not-Repeat 2026-10-07 entry (2nd/3rd occurrence, positional-args form, this session)

### Observation 32: Grilling caught 5 real gaps in check-upstream spec via mechanical verification

**Status:** OPEN
**Date:** 2026-10-07
**Type:** write-batch-checkpoint
**Session:** 
**Skill:** grilling
**Issue:** First-pass brainstorming design for check-upstream looked complete but missed: local-customizations branch going stale on submodule apply, per-plugin mirror clones duplicating shared repos (claude-plugins-official backs 5 plugins from 1 repo), a TOCTOU window in claude plugin update, mirror-clone gitignore treatment, and how to bootstrap last_reviewed_sha with no reliable installed-commit signal.
**Suggested improvement:** All 5 were found by running real commands (git log/branch on langsmith-plugin, reading known_marketplaces.json and .gitignore) rather than reasoning from the spec text alone, confirming grilling's 'verify mechanically before arguing' instruction earns its keep on config/workflow specs, not just code specs.
**Principle:** 
