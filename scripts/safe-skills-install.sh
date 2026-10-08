#!/usr/bin/env bash
# Wraps `npx skills@latest add <repo> <names...> --global --copy -y` with a
# structural safety net against its unreliable non-interactive skill-name
# filter (confirmed failing 3 times — see issue #100 and
# docs/superpowers/specs/2026-10-07-safe-skills-install-design.md).
#
# Usage: scripts/safe-skills-install.sh <repo> <skill-name> [<skill-name> ...]
# Run from the repo root (the directory containing skills/).
#
# Known caveat, not solved by this script: `--global` (passed to the
# underlying CLI below) resolves to the real ~/.claude/skills/ path
# regardless of cwd, bypassing worktree isolation. Run this from the main
# checkout, or `mv` the new/changed folders into a worktree afterward.
#
# Testing hook: set SAFE_SKILLS_INSTALL_CLI to a command to run instead of
# `npx skills@latest add` (it receives the same trailing arguments). Used by
# scripts/test-safe-skills-install.sh to simulate CLI behavior without
# hitting the network.
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <repo> <skill-name> [<skill-name> ...]" >&2
  exit 1
fi

REPO="$1"
shift
NAMES=("$@")

if [ ! -d skills ]; then
  echo "ERROR: no skills/ directory here ($(pwd)). Run this from the repo root." >&2
  exit 1
fi

CLI_CMD="${SAFE_SKILLS_INSTALL_CLI:-npx skills@latest add}"
# shellcheck disable=SC2086
$CLI_CMD "$REPO" "${NAMES[@]}" --global --copy -y
CLI_EXIT=$?

if [ "$CLI_EXIT" -ne 0 ]; then
  echo "FAILED: the install command exited $CLI_EXIT — nothing was classified or cleaned up. Check the output above." >&2
  exit "$CLI_EXIT"
fi

echo "Requested skills confirmed present:"
for n in "${NAMES[@]}"; do
  if [ -d "skills/$n" ]; then
    echo "  - $n"
  else
    echo "  - $n (MISSING — the install may not have actually included it)"
  fi
done

exit 0
