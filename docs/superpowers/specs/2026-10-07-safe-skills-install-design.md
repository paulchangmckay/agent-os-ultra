# Design: safe-skills-install wrapper

**Issue:** #100 — npx skills CLI selective-install filter is unreliable

## Problem

`npx skills@latest add <repo> <skill-names...> --global --copy -y` is supposed
to install only the named skills into `skills/`, but its non-interactive
skill-name filter has failed 3 times across separate sessions:

- Occurrence 1 (buglog bug-034): the `-s/--skill` flag didn't filter.
- Occurrence 2 (2026-10-07): the positional-args form also didn't filter —
  asked for 3 skills from `mattpocock/skills`, it installed all 38 and
  overwrote 6 already-installed skills (one locally patched).

Both prior occurrences were followed by a prose-only mitigation ("diff `git
status` and revert anything beyond what was requested," documented in
`claude-infra-reference`'s External Skill Integration Procedure, and a
cerebrum Do-Not-Repeat bullet). Neither prevented the next occurrence — a
manual post-hoc check is easy to skip under time pressure.

## Goal

Make the over-install safe-net structural instead of a thing a human has to
remember to run. Apply to every repo this procedure is used for
(`mattpocock/skills`, `Leonxlnx/taste-skill`, `timescale/pg-aiguide`,
`jakubkrehel/make-interfaces-feel-better`), not just the repo that's
actually failed so far — the CLI's unreliability isn't repo-specific, those
other repos just haven't hit it yet.

## Anti-goals

- Not trying to fix the upstream `npx skills` CLI itself (out of scope,
  third-party tool).
- Not trying to catch drift from *any* cause (a human's own stray `git add`,
  a different unrelated CLI) — scope is specifically this wrapper's own
  install runs. (A more general "prune to a declarative manifest of every
  external skill" design was considered and explicitly rejected as more
  upfront cost than this problem currently warrants — revisit only if a
  second install mechanism starts causing the same class of drift.)
- Not trying to detect or fix *under*-installation (a requested skill name
  that silently fails to install) as a primary goal — the report should
  surface it if it's obviously missing, but that's not what issue #100 is
  about and isn't required for this fix to be complete.

## Design

A new script, `scripts/safe-skills-install.sh <repo> <skill-name>
[<skill-name> ...]`, wraps the CLI call:

1. **Snapshot before.** Capture `git status --porcelain=v1 skills/` as the
   baseline. This is a delta against the baseline, not a "working tree must
   be clean" precondition — pre-existing untracked content unrelated to any
   requested skill (e.g. a skill someone is drafting by hand) must be left
   alone and not mistaken for CLI drift.

2. **Run the CLI.** `npx skills@latest add "$REPO" "${NAMES[@]}" --global
   --copy -y`.

3. **Snapshot after.** Capture `git status --porcelain=v1 skills/` again.

4. **Compute the delta** — every path under `skills/` that changed status
   between the two snapshots (new untracked, newly modified, newly deleted)
   that was NOT already in that state in the baseline.

5. **Classify each top-level `skills/<dirname>` touched by the delta** by
   matching `<dirname>` (basename only — the CLI flattens a source repo's
   category subdirectories like `skills/engineering/pr` into a flat
   `skills/pr/` on install, confirmed this session) against the requested
   name list:
   - **In the request list:** keep, even if it overwrote a previously
     installed version of that same skill — an update to a requested name
     is always the intended outcome, never something to revert.
   - **Not in the request list, and it's entirely new (wasn't present in
     the baseline at all):** `rm -rf skills/<dirname>` — the CLI pulled in
     something that wasn't asked for.
   - **Not in the request list, but the skill already existed before this
     run (an existing, previously-installed skill got modified or had
     new files added):** `git checkout -- <path>` for every tracked file
     the delta shows as modified/deleted under that dir, and `rm -rf` any
     new untracked files/subdirs the delta shows were added under that
     same dir (this is the exact failure mode from occurrence 2 — the CLI
     added `agents/` subfolders to 6 already-installed skills that weren't
     part of the request).

6. **Report.** Print a summary: which requested names are confirmed present
   under `skills/`, and — only if anything happened — a second section
   listing what was reverted/deleted and why ("unrequested new skill:
   `code-review`", "unrequested overwrite of existing skill `handoff`:
   reverted 1 file, removed 1 new path"). Exit 0 regardless of whether
   anything had to be cleaned up — the script's whole job is to make the
   end state correct, not to make the caller handle a special failure case
   for a problem it already fixed. The summary is what makes the drift
   visible, not the exit code.

## Known caveat preserved, not solved by this script

`--global` resolves to the real `~/.claude/skills/` path regardless of
`cwd`, bypassing worktree isolation (existing documented caveat). This
script doesn't change that — it should be run from the main checkout, same
as today, or its resulting new/changed files moved into a worktree
afterward. The script's own usage text should say so; no code needs to
handle it.

## Documentation update

`claude-infra-reference`'s "External Skill Integration Procedure" section —
the install-mechanism step that currently says to call `npx skills@latest
add` directly — gets updated to call `scripts/safe-skills-install.sh`
instead, for the "loose multi-skill repo, no marketplace manifest" case.
The four repos already integrated this way (mattpocock/skills, taste-skill,
pg-aiguide, make-interfaces-feel-better) each get a one-line note that
future re-syncs should use the wrapper, not the raw CLI.

## Testing

Bash script — no existing test framework in `scripts/` for shell scripts
(the repo's `node --test` setup covers `.js`/`.mjs` only). Verification is
behavioral, run against this repo's real git state in a scratch branch:

1. **Over-install case:** pick 1-2 real skill names from a small repo
   (reuse `mattpocock/skills`, it's the repo with confirmed history), run
   the wrapper requesting only those names, confirm via `git status` that
   nothing outside them landed.
2. **Pre-existing-drift case:** create an untracked throwaway file under
   `skills/` unrelated to any requested skill before running the wrapper,
   confirm it's still there and untouched afterward (proves the
   before/after delta approach, not a blanket "clean tree" check, is
   actually implemented).
3. **Overwrite-of-existing-skill case:** hand-edit one already-installed
   skill's `SKILL.md` to a marker string, then run the wrapper requesting
   *different* names from the same repo, confirm the marker string survives
   (proves revert-of-existing-skill logic fires correctly) — this is a
   reproduction of occurrence 2's exact failure mode.
4. **Reporting case:** confirm exit code is 0 and the summary output names
   anything that was reverted, for both the clean-request and the
   dirty-request runs above.
