# check-upstream: review-gated updates for linked repos and plugins

**Status:** Approved, not yet grilled
**Date:** 2026-10-07

## Context

Early on, the user avoided linking `~/.claude` to upstream GitHub repos at
all, out of concern that updates might apply automatically and overwrite
local configuration. That caution produced an inconsistent set of linkage
mechanisms, documented in CLAUDE.md §6:

- `langsmith-plugin` — a real git submodule, pointed at
  `langchain-ai/langsmith-claude-code-plugins`.
- `superpowers` and `skills/senior-engineering-partner` — originally
  submodules, deliberately converted to plain tracked files (PR #14/#16) so
  they could be edited directly. No link to upstream remains; new upstream
  commits are invisible.
- Nine marketplace-installed plugins (`claude-plugins-official`,
  `understand-anything`, `document-skills`, `context-mode`, `neuroarxiv`,
  `iso-24495-plain-language`, `refero`, `agent-stylebooks`, `typesafe-ai`) —
  installed via Claude Code's plugin manager, tracked in `settings.json`'s
  `enabledPlugins`. This is a third, separate update mechanism from git.

The user now wants to re-establish upstream links everywhere that's
missing, and — for every mechanism — gate updates behind an explicit
review step: fetch what changed, judge whether it's safe relative to this
repo's principles and any local customizations, and only then apply it on
explicit approval. Never auto-apply.

A `claude-code-guide` subagent confirmed the constraints that shape this
design (not independently re-verified against primary docs — flagged as a
verification task for whichever implementation step touches `settings.json`):

- Marketplace plugin updates are **not** git-backed — the plugin cache at
  `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` is an opaque
  copy, not a clone. There is no CLI command to view a changelog/diff before
  applying, and no `--dry-run` flag.
- Auto-update for marketplace plugins defaults to **on** for official
  marketplaces, **off** for others. It can be disabled per-marketplace via
  a `settings.json` field (reported as `autoUpdate: false` under
  `extraKnownMarketplaces`) or via `/plugin` → Marketplaces → Disable
  auto-update.
- `claude plugin update <plugin>@<marketplace>` applies an update once
  decided.

Given the plugin cache has no usable git history, the only way to get a
real diff to evaluate is to maintain a separate, read-only mirror clone of
each marketplace plugin's source repo.

This spec covers **Phase A only**: the general `check-upstream` workflow,
applied to the existing submodule (`langsmith-plugin`) and the nine
marketplace plugins. Re-submoduling `superpowers` and
`senior-engineering-partner` (**Phase B**) is a separate, higher-risk
migration (real risk of losing local edits if the upstream-base commit is
misidentified) that reuses this workflow once proven, and gets its own
spec.

## Design

### Registry file

`.wolf/upstream-sources.json` — one entry per tracked source, the single
source of truth for what `check-upstream` checks and what it considers
"already reviewed":

```json
{
  "langsmith-plugin": {
    "type": "submodule",
    "path": "langsmith-plugin",
    "upstream": "https://github.com/langchain-ai/langsmith-claude-code-plugins",
    "last_reviewed_sha": "<sha>"
  },
  "refero": {
    "type": "marketplace-mirror",
    "marketplace": "refero",
    "plugin": "refero",
    "mirror_path": "~/.claude/.upstream-mirrors/refero",
    "last_reviewed_sha": "<sha>"
  }
}
```

One entry per source for all nine marketplace plugins plus
`langsmith-plugin` — ten entries total for Phase A. `last_reviewed_sha` is
updated only when a source is actually reviewed (applied, or explicitly
dismissed — see Error Handling), never just because it was fetched.

### Mirror clones for marketplace plugins

For each marketplace plugin, `~/.claude/.upstream-mirrors/<plugin>/` holds
a plain, read-only `git clone` of that plugin's source repo (the same repo
the marketplace itself points at). This is separate from Claude Code's own
plugin cache and is never written to by anything except `git fetch` — it
exists only to give `check-upstream` a real diff to show.

Setup is one-time per plugin, done during implementation: clone each
source repo, record its path in the registry, set `last_reviewed_sha` to
the commit matching the currently-installed plugin version.

### Command: `/check-upstream [source]`

With no argument, checks every registered source. With a source name,
checks just that one.

For each source:

1. **Fetch.** Submodule: `git fetch` inside the submodule path.
   Marketplace-mirror: `git fetch` inside the mirror clone.
2. **Diff.** Compare `last_reviewed_sha..origin/HEAD` (or the relevant
   remote-tracking ref). No new commits → skip, nothing to report.
3. **Evaluate.** Claude reads the diff/commit log and judges it against
   CLAUDE.md's principles and this repo's current setup (hook contracts
   the plugin/submodule's files are relied on by, any local
   customizations). Produces one of:
   - **SAFE** — no conflict found, recommend applying.
   - **REVIEW** — a specific change needs the user's judgment (e.g. a
     behavior change, a renamed file something else depends on).
   - **CONFLICT** — a specific, named clash with a principle or local
     setup.

   Each verdict names the commit(s) or change driving it — never a bare
   label with no reasoning.
4. **Report and ask.** Show the verdict per source. Ask: apply now?
5. **Apply on yes.**
   - Submodule: bump the submodule pointer to the fetched commit, commit
     the pointer change in the main repo.
   - Marketplace-mirror: run `claude plugin update <plugin>@<marketplace>`.
   - Either way: update `last_reviewed_sha` in the registry to the commit
     just applied.
6. **On no:** leave `last_reviewed_sha` unchanged, move to the next
   source. The unreviewed commits surface again next run.

### Auto-update gate

Marketplace auto-update must be off for every marketplace in the registry
— otherwise an official-marketplace plugin could update itself in the
background between `check-upstream` runs, defeating the gate. This is a
`settings.json` change, made through the `update-config` skill at
implementation time (not a raw edit — `settings.json` edits are
classifier-gated in this environment per CLAUDE.md §3). The exact field
name and shape must be verified against actual Claude Code behavior at
that point, not assumed from this spec's research summary.

## Error handling

- **Mirror clone fetch fails** (network, repo moved): report it as a
  per-source error in the `/check-upstream` output, continue checking
  other sources. Don't abort the whole run for one bad source.
- **Submodule has local, uncommitted changes** when an update is about to
  be applied: refuse to bump the pointer, surface the dirty state, same as
  the existing git-safety posture in CLAUDE.md's "Executing actions with
  care" section.
- **No entry in the registry for an installed plugin or submodule**: this
  is a setup gap, not a runtime error — `check-upstream` lists any
  submodule or enabled marketplace plugin missing from the registry so the
  gap gets noticed, but does not block checking the sources that are
  registered.

## Testing

- Dry run against `langsmith-plugin` (already a real submodule with real
  upstream history) first — lowest-risk proof that fetch/diff/evaluate/
  apply works end to end before setting up nine mirror clones.
- For marketplace plugins: verify the mirror-clone diff actually matches
  what `claude plugin update` would apply, by checking the mirror's
  `origin/HEAD` against the version string the plugin manifest reports
  after updating.
- Verify the auto-update-off setting actually prevents a background
  update: after disabling it for one marketplace, confirm no version
  change occurs across a few sessions without an explicit
  `claude plugin update` call.
