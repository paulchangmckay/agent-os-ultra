# bloat-audit diff mode

**Status:** Approved, pending grilling
**Date:** 2026-10-07

## Context

Checking the upstream [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail)
repo for capability drift since this repo's original adoption spec
(`2026-07-15-ponytail-bloat-tooling-design.md`, which cloned three pieces:
`debt-ledger`, `bloat-audit`, and subagent-rule propagation). Upstream went
from v4.9.0 to v4.13.0 (Aug-Oct 2026) and added `/ponytail-review`: a
diff-scoped over-engineering review (`uncommitted`/`staged`/`branch`/PR-link
targeting) that didn't exist when the original spec was written — at that
time ponytail only had the whole-repo `/ponytail-audit`, which this repo
already cloned as `skills/bloat-audit`.

Initial plan was to fold ponytail's 5-tag taxonomy into this repo's existing
`simplify` skill, since `simplify` already does diff-scoped reuse/
simplification/efficiency cleanup with auto-fix — functionally close to
`/ponytail-review`. Checked: `simplify` is a built-in Claude Code skill with
no local `SKILL.md` anywhere on disk (confirmed via filesystem search), so it
can't be edited. Revised plan: extend `skills/bloat-audit/SKILL.md` instead,
which is a file this repo owns and already carries the exact tag taxonomy
(`delete/stdlib/native/yagni/shrink`) `/ponytail-review` would need.

## Design

### Scope: two modes, one skill

- **No target named** → whole-repo scan (existing behavior, unchanged).
- **Target named in plain words** → diff-scoped scan against that target's
  `git diff` instead of the full tree.

### Targets

| Target phrase | Diff command |
|---|---|
| `uncommitted` | `git diff` |
| `staged` | `git diff --staged` |
| `branch` | `git diff origin/main...HEAD` (fall back to local `main...HEAD` if no `origin` remote) |
| PR number or link | `gh pr diff <ref>` |

Target detection is natural-language, same as ponytail-review's own
convention ("name a target in plain words to narrow or widen it") — the
skill body instructs matching the user's phrasing against this table rather
than requiring an exact keyword.

### Tags and output — unchanged

Same five tags, same per-line format, same closing line. Diff mode only
changes what gets scanned, not how a finding is reported:

```
delete: dead code, unused flexibility, speculative feature. Replacement: nothing.
stdlib: hand-rolled thing the standard library already ships. Name the function.
native: dependency or code doing what the platform already does. Name the feature.
yagni: abstraction with one implementation, config nobody sets, layer with one caller.
shrink: same logic, fewer lines. Show the shorter form.
```

Output: one line per finding, ranked biggest cut first:
`<tag> <what to cut>. <replacement>. [path]`. Ends with
`net: -N lines, -M deps possible.`, or `Lean already. Ship.` if nothing
qualifies — identical closing convention in both modes.

### Boundary — unchanged, both modes

Read-only in both modes. Lists findings, applies nothing. Matches this
skill's existing boundary and ponytail-review's own behavior ("hands back a
delete-list," no auto-apply). Correctness bugs, security holes, and
performance stay out of scope in both modes, routed to
`senior-engineering-partner`'s `AUDIT:` mode or `/code-review`, same as
today.

### Frontmatter change

`description` currently frames the skill as whole-repo only
("Whole-repo audit for over-engineering..."). Broaden it to cover both
modes and add diff-scoped trigger phrases: "review this diff for
over-engineering", "audit the branch/PR for bloat", "find bloat in this
diff" — alongside the existing whole-repo phrases, so the skill still
auto-fires on either framing.

### PR-link dependency

Uses `gh pr diff <ref>` — no new tool dependency in practice, since `gh` is
already relied on elsewhere in this repo's workflow (`github-issue-first`,
`requesting-code-review`).

## Out of scope

- No intensity levels (`lite`/`full`/`ultra`/`off`) — upstream added these
  in the same release window, but this repo's original spec already
  declined them as "not requested," and nothing about that has changed.
- No `/ponytail-gain`-style benchmark scoreboard — cosmetic, not adopted.
- No changes to `debt-ledger` or the subagent-propagation hook — both
  pieces from the original spec are unaffected by this change.
- No new standalone skill — folded into `bloat-audit` per user decision,
  rather than creating a `ponytail-review`-named sibling.
- No auto-fix in diff mode — stays read-only like the existing whole-repo
  mode, per user decision.

## Testing

- Seed a scratch diff (uncommitted change containing one obvious `yagni:`-
  tagged single-implementation abstraction) and confirm the skill, run with
  target `uncommitted`, reports it and only it (not unrelated whole-tree
  findings).
- Run with no target named against this repo and confirm it still produces
  the existing whole-repo-scan output shape (regression check against
  current behavior).
- Run with target `branch` on a scratch branch with one committed change
  ahead of `main` and confirm the diff is scoped to that branch's commits,
  not the whole tree.
- PR-link target: smoke-test against any open PR in this repo (or skip with
  a note if none are open) and confirm `gh pr diff` output feeds the same
  tag/output pipeline without error.
