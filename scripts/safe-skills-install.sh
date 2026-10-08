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

hash_skills() {
  find skills -type f | sort | while IFS= read -r f; do
    sha256sum "$f"
  done
}

HEAD_BEFORE=$(git rev-parse HEAD)
HASHES_BEFORE=$(hash_skills)

CLI_CMD="${SAFE_SKILLS_INSTALL_CLI:-npx skills@latest add}"
# shellcheck disable=SC2086
$CLI_CMD "$REPO" "${NAMES[@]}" --global --copy -y
CLI_EXIT=$?

if [ "$CLI_EXIT" -ne 0 ]; then
  echo "FAILED: the install command exited $CLI_EXIT — nothing was classified or cleaned up. Check the output above." >&2
  exit "$CLI_EXIT"
fi

HEAD_AFTER=$(git rev-parse HEAD)
HASHES_AFTER=$(hash_skills)

if [ "$HEAD_BEFORE" != "$HEAD_AFTER" ]; then
  echo "ABORTED: HEAD moved ($HEAD_BEFORE -> $HEAD_AFTER) during this run — a commit landed from somewhere else (likely a concurrent session). No automated cleanup was performed; review by hand:" >&2
  diff <(echo "$HASHES_BEFORE") <(echo "$HASHES_AFTER") >&2
  exit 1
fi

name_in() {
  local needle="$1"
  shift
  local x
  for x in "$@"; do
    [ "$x" = "$needle" ] && return 0
  done
  return 1
}

PRE_EXISTING_TOPDIRS=()
while IFS= read -r topdir; do
  [ -n "$topdir" ] && PRE_EXISTING_TOPDIRS+=("$topdir")
done < <(
  echo "$HASHES_BEFORE" \
    | awk '{print $2}' \
    | sed -n 's#^skills/\([^/]*\).*$#\1#p' \
    | sort -u
)

CHANGED_RELPATHS=()
while IFS= read -r rel; do
  [ -n "$rel" ] && CHANGED_RELPATHS+=("$rel")
done < <(
  diff <(echo "$HASHES_BEFORE") <(echo "$HASHES_AFTER") \
    | grep -E '^[<>] ' \
    | awk '{print $3}' \
    | sed -n 's#^skills/##p' \
    | sort -u
)

UNRECOGNIZED_NESTED=()
for rel in "${CHANGED_RELPATHS[@]}"; do
  topdir="${rel%%/*}"
  if ! name_in "$topdir" "${NAMES[@]}" && ! name_in "$topdir" "${PRE_EXISTING_TOPDIRS[@]}"; then
    segcount=$(echo "$rel" | awk -F/ '{print NF}')
    if [ "$segcount" -gt 2 ]; then
      UNRECOGNIZED_NESTED+=("$rel")
    fi
  fi
done

if [ "${#UNRECOGNIZED_NESTED[@]}" -gt 0 ]; then
  echo "ABORTED: unexpected nested path(s) under an unrecognized top-level directory — can't safely tell whether this is a stray category directory wrapping a real skill. No automated cleanup was performed; review by hand:" >&2
  printf '  %s\n' "${UNRECOGNIZED_NESTED[@]}" >&2
  exit 1
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
