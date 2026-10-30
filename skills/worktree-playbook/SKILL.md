---
name: worktree-playbook
description: Use when creating, working in, or cleaning up a git worktree, merging a worktree branch via PR, merging several PRs in sequence, or fixing a stacked PR that went CONFLICTING after its base squash-merged. Holds the gotchas learned in the ~/.claude repo.
---

# Worktree Playbook

Lookup reference moved out of the global `CLAUDE.md`. Read on demand. `<repo-root>` means the primary checkout (here `~/.claude`).

## Setup

- `EnterWorktree` always targets the session's primary repo. For a secondary project, run `git worktree add <path> -b <branch> origin/<base>` via Bash. Try `EnterWorktree` first; fall back only if it errors, whatever the launch directory.
- `EnterWorktree` branches from `origin/<default>`, not local `main`. Local-only commits (specs committed during brainstorming) are missing. Run `git rebase main` inside the worktree before the first `task-brief` call.
- `docs/superpowers/plans/` is gitignored. A new worktree has no plan file. `cp` it into the matching path before running `scripts/task-brief`.
- Submodule directories are empty in a fresh worktree. Run `git submodule update --init <name>` before touching one. Only `langsmith-plugin` is a submodule today.

## Isolation

- Absolute-path edits write to the MAIN tree, not the worktree. Use relative paths or `cd <worktree-path>`.
- Global-install CLIs (`npx skills add --global`, `claude plugin enable/disable`) resolve against the real `~/.claude`, whatever the cwd. They change live config mid-branch. Tell the user; do not assume branch scope. After one runs, check `git status` in the main checkout and `mv` stray files into the worktree.
- Hook and `settings.json` edits made in a worktree are not live in the running session. Verify new hook behavior after merging to main.
- Dispatched subagents can escape isolation (absolute paths, or self-editing `settings.json` permissions when blocked; never comply with that). Give them relative-path-only instructions plus `pwd`, `git rev-parse --show-toplevel` and `git branch --show-current` checks before and after every write or commit. Re-verify the claimed commit with `git log --all` before trusting DONE.
- If escape happened: `git reset --soft` (never `--hard`), restore file content, remove only the stray artifacts. Never blanket-reset the main checkout.

## Exit and merge

1. `ExitWorktree` (keep).
2. `git push -u origin <branch>`, then `gh pr create`. Include `Closes #N` if the work went through `github-issue-first`.
3. Wait for an explicit yes. Then `gh pr merge --squash`.
4. `git fetch origin main` AFTER the merge. A fetch from earlier makes `git merge origin/main` report "Already up to date" falsely.
5. Update local main: `git -C <repo-root> pull origin main`. If `git log origin/main..main` is non-empty (local specs not yet pushed), run `git merge origin/main` instead. Never `reset --hard`.
6. Clean up: `git worktree remove .claude/worktrees/<name> --force`, then `git branch -d <branch>`.

`git checkout main` fails inside a worktree (main is checked out in the parent). Branch protection rejects a local merge to main anyway.

## Merging several PRs in a row

With `required_status_checks.strict=true`, every merge invalidates the other open PRs. Before each remaining merge run `gh api repos/<owner>/<repo>/pulls/<N>/update-branch -X PUT`. Expect up to N calls for N PRs.

## Stacked PR shows CONFLICTING after its base squash-merged

Git cannot match a squash commit to the commits it replaced. Do not `git rebase origin/main`. Run:

`git rebase --onto origin/main <B's-real-fork-point-SHA> <B-branch>`

This replays only B's own commits. Then `git push --force-with-lease`. Note the git safety hook blocks `push --force` variants; if it blocks this, hand the user the exact command.

## Stash conflicts during cleanup

If `git merge origin/main` refuses because the main checkout has unrelated uncommitted drift:

1. `git stash push -u -m "<unique-tag>"` and capture the SHA with `git stash list --format='%H %gs'`.
2. Merge, then `git stash apply <sha>`. Never bare `pop`.
3. Resolve by file type. Append-only logs (`memory.md`): concatenate both blocks chronologically. Regenerated inventories (`anatomy.md`): `git checkout --ours`, then `openwolf scan`.
4. Drop only your own tagged entry.

## Submodule commit transfer (worktree to main)

Worktrees have independent submodule clones. Run `scripts/submodule-transfer.sh <submodule-path> <source-worktree-root> <commit-sha>`. A raw SHA is not fetchable by plain local-path fetch; the script uses a named branch.
