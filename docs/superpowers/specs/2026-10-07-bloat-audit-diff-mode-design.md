# bloat-audit diff mode

**Status:** Approved, grilled
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

### Exclusions — unchanged, both modes

Whole-repo mode excludes `.git`, `node_modules`, and every submodule path
listed in `.gitmodules` (read dynamically, same logic `debt-ledger` uses) —
vendored/upstream code isn't this repo's bloat to report. Diff mode applies
the identical exclusion: a diff that only touches an excluded path (e.g. a
submodule pointer bump) behaves like an empty diff for this skill's
purposes. Considered dropping exclusions in diff mode (a diff is already
narrow by construction) and rejected it during grilling — consistency with
the existing whole-repo rule matters more than the marginal narrowing, and
a PR that happens to touch vendored code still shouldn't get flagged as
this repo's bloat.

### Scope: two modes, one skill

- **No target named** → whole-repo scan (existing behavior, unchanged).
- **Target named in plain words** → diff-scoped scan against that target's
  `git diff` instead of the full tree.

### Targets

| Target phrase | Diff command |
|---|---|
| `uncommitted` | `git diff HEAD`, plus a null-delimited `git ls-files --others --exclude-standard` loop through `git diff --no-index` for untracked files |
| `staged` | `git diff --staged` |
| `branch` | diff against the repo's actual default branch — resolve it with `git symbolic-ref --short refs/remotes/origin/HEAD` (fast, local; fallback: `git remote show origin \| sed -n 's/.*HEAD branch: //p'`), then `git diff origin/<default>...HEAD` |
| PR number, URL, or branch name | `gh pr diff <ref>` — `gh` accepts all three forms natively (confirmed via `gh pr diff --help`: `USAGE: gh pr diff [<number> \| <url> \| <branch>]`), no parsing needed on this skill's side |

Target detection is natural-language, same as ponytail-review's own
convention ("name a target in plain words to narrow or widen it") — the
skill body instructs matching the user's phrasing against this table rather
than requiring an exact keyword. The bare word `branch` means "diff the
current branch against the resolved default branch"; any other branch name
(not the literal word `branch`) is treated as a `gh pr diff` target, same as
a PR number or URL.

`uncommitted` uses `git diff HEAD` rather than plain `git diff`: plain
`git diff` only compares working tree to index, so it misses anything
already `git add`ed. `git diff HEAD` is a strict superset — it catches
staged and unstaged tracked changes alike — and is still read-only. The
untracked-file loop is unaffected by this change (`git diff HEAD` still
doesn't show untracked files, so the loop is still needed).

Branch resolution runs the fast local check first and the network check
second, in that order, each extracting just the branch name from the
command's raw output: `git symbolic-ref --short refs/remotes/origin/HEAD`
resolves instantly and returns the name directly (e.g. `origin/main`) with
no parsing needed; the fallback `git remote show origin | sed -n 's/.*HEAD
branch: //p'` makes a network call and needs the `sed` extraction because
the raw command prints `  HEAD branch: main`, not just `main`. If there's
no `origin` remote at all, that's an ordinary git-command failure per
Failure handling below — surface it and stop, never guess at a default
branch name. (Rejected: guessing a local `<default>...HEAD` fallback with
no remote to resolve a name from — there is no reliable way to know the
default branch name without asking a remote.)

Hardcoding `main` was considered and rejected during grilling: this skill
can run in any project, not just this repo, and a hardcoded branch name
would silently produce an empty or wrong diff in a repo whose default
branch is `master` or `trunk`. Dynamic resolution costs one extra command
and removes that failure mode.

The branch diff uses three-dot (`...`, merge-base) comparison, not two-dot
— it shows what the current branch would introduce, not a raw snapshot
diff against wherever the default branch currently sits (which would also
surface not-yet-merged default-branch changes as noise).

Diff-mode shell commands live in fenced code blocks in the skill body
rather than raw inside markdown table cells — a table cell containing a
real pipe needs a `\|` escape to not break the table's column syntax, but
an agent copying that raw text verbatim into a shell would copy the
literal backslash too, silently breaking the command (a backslash-escaped
pipe in bash is a literal `|` argument character, not a pipe operator).
Only `staged` and the PR-link row stay inline in the table — both are
single commands with no pipe character, so no escaping issue applies.

### Failure handling

- **`gh` fails** (not installed, not authenticated, bad ref): surface gh's
  own error message and stop. No silent fallback to a different scope —
  same no-ops-gracefully pattern `github-issue-first` already uses for its
  own `gh` dependency. Generalizes to any git command failing for the same
  reason (e.g. no git repository found): report the error, stop, don't
  guess at a substitute scope.
- **Requested diff is empty** (clean uncommitted tree, nothing staged,
  branch has no commits ahead of default): output a distinct
  `No <target> changes to scan.` This is deliberately different from
  `Lean already. Ship.`, which means a real scan ran against real content
  and found zero bloat — collapsing the two would make "there was nothing
  here to look at" indistinguishable from "I looked and it's clean."

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
`net: -N lines, -M deps possible.`, or `Lean already. Ship.` if a scan ran
and found nothing — identical closing convention in both modes. (If there
was no diff to scan at all, see Failure handling above for the distinct
`No <target> changes to scan.` case.)

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
- Run with target `uncommitted` on a clean tree (no uncommitted changes)
  and confirm the output is `No uncommitted changes to scan.`, distinct
  from `Lean already. Ship.`
- Stage a scratch file with no commit and confirm the `uncommitted` target
  reports it: `git diff HEAD` (unlike plain `git diff`) shows staged-but-
  uncommitted tracked changes, which is the specific gap this mechanism
  fixes.
- Seed a diff that touches only an excluded path (e.g. a submodule pointer
  bump) and confirm it's treated as empty, not scanned for bloat.
- Confirm default-branch resolution: run `git symbolic-ref --short
  refs/remotes/origin/HEAD` against this repo and verify it returns `main`
  (matches `gh repo view --json defaultBranchRef`, both already confirmed
  during grilling) — the branch target's dynamic lookup should produce the
  same value, not a hardcoded one. This is the fast local check and should
  succeed directly, without needing the `git remote show origin` network
  fallback.
