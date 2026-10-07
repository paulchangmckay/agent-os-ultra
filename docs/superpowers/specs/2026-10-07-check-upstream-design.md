# check-upstream: review-gated updates for linked repos and plugins

**Status:** Approved, grilled
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

Mechanically confirmed during grilling:

- `plugins/known_marketplaces.json` maps **marketplace → one GitHub repo**,
  and several repos back more than one enabled plugin.
  `claude-plugins-official` alone backs five
  (`security-guidance`/`skill-creator`/`feature-dev`/`plugin-dev`/
  `ba-agent`) from one repo (`anthropics/claude-plugins-official`). A mirror
  must be per-repo, not per-plugin, or sibling-plugin changes pollute each
  other's evaluation.
- `superpowers-dev`'s marketplace source is
  `{"source": "directory", "path": ".../superpowers"}` — a local-folder
  plugin source, not a remote repo. The plugin layer gives superpowers zero
  upstream linkage today, same as the vendored-files situation above —
  confirming Phase B is the only path back to a real upstream link for it.
- `plugins/marketplaces/<name>/` (the installed-plugin content on disk) is
  not itself a separate git clone — it's a plain gitignored directory
  inside this repo's working tree (`plugins/` is excluded wholesale in
  `.gitignore`), confirming the "not git-backed" finding directly rather
  than relying on the research subagent's word for it.

This spec covers **Phase A only**: the general `check-upstream` workflow,
applied to the existing submodule (`langsmith-plugin`) and the nine
marketplace plugins. Re-submoduling `superpowers` and
`senior-engineering-partner` (**Phase B**) is a separate, higher-risk
migration (real risk of losing local edits if the upstream-base commit is
misidentified) that reuses this workflow once proven, and gets its own
spec.

## Design

### Registry file

`.wolf/upstream-sources.json` — one entry per tracked **source** (a
submodule, or a repo backing one or more marketplace plugins), the single
source of truth for what `check-upstream` checks and what it considers
"already reviewed". Marketplace entries are keyed by repo, with a nested
map for the plugin(s) that repo backs — this is the per-repo-mirror /
per-plugin-subpath fix from grilling, not the original per-plugin-only
draft:

```json
{
  "langsmith-plugin": {
    "type": "submodule",
    "path": "langsmith-plugin",
    "upstream": "https://github.com/langchain-ai/langsmith-claude-code-plugins",
    "last_reviewed_sha": "<sha>"
  },
  "claude-plugins-official": {
    "type": "marketplace-mirror",
    "marketplace": "claude-plugins-official",
    "repo": "anthropics/claude-plugins-official",
    "mirror_path": "~/.claude/.upstream-mirrors/claude-plugins-official",
    "plugins": {
      "security-guidance": {"subpath": "<discovered during setup>", "last_reviewed_sha": "<sha>"},
      "skill-creator": {"subpath": "<discovered during setup>", "last_reviewed_sha": "<sha>"},
      "feature-dev": {"subpath": "<discovered during setup>", "last_reviewed_sha": "<sha>"},
      "plugin-dev": {"subpath": "<discovered during setup>", "last_reviewed_sha": "<sha>"},
      "ba-agent": {"subpath": "<discovered during setup>", "last_reviewed_sha": "<sha>"}
    }
  },
  "refero": {
    "type": "marketplace-mirror",
    "marketplace": "refero",
    "repo": "referodesign/refero_skill",
    "mirror_path": "~/.claude/.upstream-mirrors/refero",
    "plugins": {
      "refero": {"subpath": ".", "last_reviewed_sha": "<sha>"}
    }
  }
}
```

One entry per distinct repo. For Phase A that's `langsmith-plugin` plus
however many distinct repos the nine marketplace plugins resolve to (one
repo, `claude-plugins-official`, covers five of them; the rest are
presumably 1:1 but that gets confirmed during setup, not assumed here).
`last_reviewed_sha` — at the plugin level for marketplace entries, at the
source level for submodules — is updated only when that specific thing is
actually reviewed (applied, or explicitly dismissed — see Error Handling),
never just because the repo was fetched.

One registry entry (`context-mode@context-mode`) could not be traced to a
marketplace source in `known_marketplaces.json` during grilling — flagged
for discovery at setup time, not resolved here; falls under the "missing
from registry" handling below if it turns out not to be a diffable git
source at all (e.g. an MCP-only plugin with nothing upstream to compare).

### Mirror clones for marketplace plugins

For each distinct repo, `~/.claude/.upstream-mirrors/<repo-name>/` holds a
plain, read-only `git clone` of that repo. This is separate from Claude
Code's own plugin cache and is never written to by anything except
`git fetch` — it exists only to give `check-upstream` a real diff to show.
`.upstream-mirrors/` is added to `.gitignore`: these clones are
regenerable derived content (same category as the plugin cache, per the
portable-repo generated-file rule) — if one goes missing, `check-upstream`
just re-clones it, since a mirror only ever tracks upstream HEAD and never
holds anything unique.

Setup is one-time per repo, done during implementation:

1. Clone the source repo into its mirror path.
2. For a shared repo, inspect it to find each plugin's subpath (its own
   directory within the repo) and record it per-plugin in the registry.
3. Bootstrap `last_reviewed_sha` (per-plugin, or per-source for a
   1:1 repo) to the mirror's current `HEAD` at the moment of setup —
   the plugin cache doesn't reliably expose which exact upstream commit is
   installed, so "whatever upstream has right now" is treated as the
   already-reviewed baseline. If the installed version actually lags
   upstream by a few commits, this just means those commits won't be
   flagged on the first run — safe direction to be wrong in, since it
   under-reports already-shipped history rather than over-reporting work
   that was never installed.

### Command: `/check-upstream [source]`

With no argument, checks every registered source. With a source name,
checks just that one.

For each source:

1. **Fetch.** Submodule: `git fetch` inside the submodule path.
   Marketplace-mirror: `git fetch` inside the mirror clone (once per repo,
   even if it backs several plugins).
2. **Diff.** Submodule: compare `last_reviewed_sha..origin/HEAD`.
   Marketplace-mirror, per plugin: compare `last_reviewed_sha..origin/HEAD`
   **scoped to that plugin's subpath** (`git log`/`git diff -- <subpath>`),
   so a sibling plugin's changes in the same repo never appear in this
   plugin's evaluation. No new commits in scope → skip, nothing to report.
3. **Evaluate.** Claude reads the (scoped) diff/commit log and judges it
   against CLAUDE.md's principles and this repo's current setup (hook
   contracts the plugin/submodule's files are relied on by, any local
   customizations). Produces one of:
   - **SAFE** — no conflict found, recommend applying.
   - **REVIEW** — a specific change needs the user's judgment (e.g. a
     behavior change, a renamed file something else depends on).
   - **CONFLICT** — a specific, named clash with a principle or local
     setup.

   Each verdict names the commit(s) or change driving it — never a bare
   label with no reasoning.
4. **Report and ask.** Show the verdict per source (per plugin, for a
   shared repo). Ask: apply now?
5. **Apply on yes.**
   - Submodule: bump the submodule pointer to the fetched commit, commit
     the pointer change in the main repo, then fast-forward that
     submodule's `local-customizations` branch to match — this keeps the
     existing documented habit (CLAUDE.md §6) intact instead of letting it
     go stale once `check-upstream` starts touching these submodules.
   - Marketplace-mirror: run `claude plugin update <plugin>@<marketplace>`.
     `claude plugin update` always pulls whatever the marketplace catalog
     currently has — there's no flag to pin it to the exact commit just
     reviewed. Evaluate-then-apply happen back-to-back in the same command
     invocation, so the window for upstream to gain further, unreviewed
     commits in between is accepted as negligible; no extra re-check.
   - Either way: update `last_reviewed_sha` (per-plugin for marketplace
     sources) in the registry to the commit just applied.
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

- Add `.upstream-mirrors/` to `.gitignore` before the first mirror clone
  exists, and confirm `git status` shows it clean afterward.
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
