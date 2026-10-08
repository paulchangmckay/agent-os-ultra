---
name: bloat-audit
description: >
  Audit for over-engineering: dead code, single-implementation
  abstractions, hand-rolled reimplementations of the stdlib or an installed
  dependency, unused flexibility. Whole-repo by default, or scoped to a
  diff when a target is named. Ranked, read-only, one-shot report — does
  not apply fixes. Use when the user says "audit this codebase for
  over-engineering", "what can I delete from this repo", "find bloat",
  "bloat audit", "audit for bloat", "review this diff for
  over-engineering", "audit the branch/PR for bloat", or "find bloat in
  this diff". Correctness bugs, security holes, and performance are out of
  scope — route those to senior-engineering-partner's AUDIT: mode or a
  normal code review instead.
---

No target named: scan the whole tree. Target named in plain words
(`uncommitted`, `staged`, `branch`, or a PR number/URL/branch name): scan
only that target's diff. Rank findings biggest cut first in both modes.

## Exclusions

Exclude the same paths in both modes: `.git`, `node_modules`, and every
submodule path listed in `.gitmodules` (read dynamically, same logic
`debt-ledger` uses) — vendored/upstream code isn't this repo's bloat to
report. A diff touching only excluded paths (e.g. a submodule pointer
bump) behaves like an empty diff for this skill's purposes.

## Targets (diff mode)

| Target phrase | Diff command |
|---|---|
| `uncommitted` | see below — tracked changes (staged and unstaged) plus untracked files |
| `staged` | `git diff --staged` |
| `branch` | see below — resolves the repo's actual default branch, then diffs against it |
| PR number, URL, or branch name | `gh pr diff <ref>` — `gh` accepts all three forms natively, no parsing needed |

The bare word `branch` means "diff the current branch against the resolved
default branch." Any other branch name (not the literal word `branch`) is
treated as a `gh pr diff` target, same as a PR number or URL.

**`uncommitted`:**

```bash
git diff HEAD
git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
  git diff --no-index -- /dev/null "$f"
done
```

`git diff HEAD` covers tracked modifications — staged and unstaged alike,
since comparing against `HEAD` (not the index) catches anything already
`git add`ed as well as working-tree-only edits; plain `git diff` would miss
staged changes. The null-delimited loop covers untracked files via `git
diff --no-index`, which compares paths directly without touching the index
— `git diff HEAD` still doesn't show untracked files, so the loop is still
needed. `git diff --no-index` exits 1 when it finds a difference —
expected, not a failure. No index mutation, so there's nothing to clean up
and no empty-file-list edge case to guard.

**`branch`:**

```bash
git symbolic-ref --short refs/remotes/origin/HEAD
```

Fast and local — resolves directly to the fully-qualified ref the diff
command needs below (e.g. `origin/main`), nothing further to extract. If
it fails (e.g. `origin/HEAD` isn't set locally — rare, but possible after
a shallow or partial clone), fall back to the network call:

```bash
git remote show origin | sed -n 's/.*HEAD branch: //p'
```

This prints only the bare branch name (e.g. `main`) from the raw `  HEAD
branch: main` line `git remote show origin` outputs — prefix it with
`origin/` before using it below, since this path (unlike the first) hasn't
already qualified it with the remote name. If there's no `origin` remote
at all, that's a failure per Failure handling below — surface it and stop,
don't guess at a default branch name. This pipeline's own exit code can't
be trusted for that check — a missing remote makes `git remote show` fail,
but piping into `sed` means the pipeline's exit status is `sed`'s, which
exits 0 on empty input regardless. Treat empty output from this fallback
(including the rare `HEAD branch: (unknown)` case, which `sed` happily
extracts as the literal string `(unknown)`) as the same failure: surface
that no default branch could be resolved and stop, don't build
`origin/(unknown)` or an empty ref and run the diff anyway.

Once resolved to a fully-qualified ref (`origin/<name>`), diff with
three-dot (`...`, merge-base) comparison, not two-dot: `git diff
origin/<name>...HEAD` — this shows what the current branch would
introduce, not a raw snapshot diff against wherever the default branch
currently sits (which would also surface not-yet-merged default-branch
changes as noise).

Never hardcode a branch name (`main`, `master`, etc.) — a hardcoded name
silently produces an empty or wrong diff in a repo with a different
default branch.

## Failure handling

- `gh` fails (not installed, not authenticated, bad ref), or any git
  command fails (e.g. no git repository found): surface the tool's own
  error message and stop. No silent fallback to a different scope.
- Requested diff is empty (clean uncommitted tree, nothing staged, branch
  has no commits ahead of default, or diff touches only excluded paths):
  output `No <target> changes to scan.` — distinct from `Lean already.
  Ship.`, which means a real scan ran and found zero bloat.

## Tags

- `delete:` dead code, unused flexibility, speculative feature. Replacement: nothing.
- `stdlib:` hand-rolled thing the standard library already ships. Name the function.
- `native:` dependency or code doing what the platform already does. Name the feature.
- `yagni:` abstraction with one implementation, config nobody sets, layer with one caller.
- `shrink:` same logic, fewer lines. Show the shorter form.

## Hunt

Deps the stdlib or platform already ships, single-implementation interfaces,
factories with one product, wrappers that only delegate, files exporting one
thing, dead flags and config, hand-rolled stdlib. Dependency-bloat findings
(`package.json`/`requirements.txt` vs. actual imports) are model judgment —
read the manifest and the imports and reason about it. No tooling dependency
(no `depcheck` etc.) — would only cover JS anyway, and this repo also has
Python/bash/skill-file content such a tool can't see.

## Output

One line per finding, ranked: `<tag> <what to cut>. <replacement>. [path]`.
End with `net: -N lines, -M deps possible.` Nothing to cut after a real
scan: `Lean already. Ship.` No diff to scan at all: `No <target> changes
to scan.`

## Boundaries

Scope: over-engineering and complexity only, in both modes. Correctness
bugs, security holes, and performance route to
`senior-engineering-partner`'s `AUDIT:` mode or a normal code-review pass
instead. Lists findings, applies nothing. One-shot.
