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
# regardless of cwd, bypassing worktree isolation. This script must be run
# from the main checkout; it will refuse to run anywhere else (see the
# worktree guard below).
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

# --global (passed to the underlying CLI) always writes to the real
# ~/.claude/skills/, but everything below only ever looks at ./skills
# relative to cwd. From inside a worktree those are different trees, so the
# script would see no changes and silently report nothing to clean up —
# exactly backwards for a safety net. git-dir and git-common-dir diverge
# only in a linked worktree.
GIT_DIR_RAW=$(git rev-parse --git-dir 2>/dev/null)
GIT_COMMON_DIR_RAW=$(git rev-parse --git-common-dir 2>/dev/null)
if [ -n "$GIT_DIR_RAW" ] && [ -n "$GIT_COMMON_DIR_RAW" ]; then
  GIT_DIR_ABS=$(cd "$GIT_DIR_RAW" 2>/dev/null && pwd)
  GIT_COMMON_DIR_ABS=$(cd "$GIT_COMMON_DIR_RAW" 2>/dev/null && pwd)
  if [ "$GIT_DIR_ABS" != "$GIT_COMMON_DIR_ABS" ]; then
    echo "ERROR: this looks like a git worktree, not the main checkout. --global (passed to the underlying CLI) always writes to the real ~/.claude/skills/ regardless of cwd, but this script's snapshot only ever looks at ./skills here — it would miss the real changes entirely. This script must be run from the main checkout; it will refuse to run anywhere else." >&2
    exit 1
  fi
fi

# sha256sum isn't guaranteed on a plain macOS install. Fall back to
# `shasum -a 256`, which ships by default and produces the same
# "<hash>  <path>" output format. Abort loudly rather than failing open
# (hashing nothing, seeing no changes, cleaning nothing up, exiting 0).
if command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  HASH_CMD=(shasum -a 256)
else
  echo "ERROR: neither sha256sum nor shasum is available on PATH — cannot safely hash skills/ contents." >&2
  exit 1
fi

# find without -L doesn't follow a symlinked topdir when recursing, so a
# symlink (e.g. skills/brainstorming -> ../superpowers/skills/brainstorming)
# shows up here as the symlink entry itself, never traversed into. Treat it
# as a first-class, hashable entity via its own readlink target rather than
# ignoring it (the old content-hash-only approach made every symlinked or
# empty topdir invisible to change detection).
hash_skills() {
  find skills -mindepth 1 \( -type f -o -type l \) | sort | while IFS= read -r f; do
    if [ -L "$f" ]; then
      printf 'symlink:%s  %s\n' "$(readlink -- "$f")" "$f"
    else
      "${HASH_CMD[@]}" "$f"
    fi
  done
}

# PRE_EXISTING_TOPDIRS must reflect an actual directory listing, not file
# content hashes — an empty pre-existing directory or a symlinked topdir has
# no file-content hash lines to derive it from, so it would otherwise be
# misclassified as "never seen before" and wrongly rm -rf'd wholesale. No
# -type filter here: a plain top-level file under skills/ is just as
# pre-existing as a directory or symlink, and excluding it previously meant
# the CLI touching one got it misclassified as a brand-new skill and removed.
PRE_EXISTING_TOPDIRS=()
while IFS= read -r topdir; do
  [ -n "$topdir" ] && PRE_EXISTING_TOPDIRS+=("$topdir")
done < <(
  find skills -mindepth 1 -maxdepth 1 -exec basename {} \; | sort -u
)

# Full backup of skills/ before the CLI runs, so a revert can restore the
# exact prior bytes/symlink at an exact path instead of resetting an entire
# directory via git. -a (archive) preserves symlinks as symlinks rather than
# following them.
if ! BACKUP_DIR=$(mktemp -d); then
  echo "ERROR: mktemp -d failed — cannot create a backup before running the install. Aborting without running the CLI." >&2
  exit 1
fi
trap 'rm -rf "$BACKUP_DIR"' EXIT

if ! cp -a skills "$BACKUP_DIR/skills-before"; then
  echo "ERROR: failed to back up skills/ to $BACKUP_DIR/skills-before — cannot safely run the install without a backup. Aborting without running the CLI." >&2
  exit 1
fi

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
for rel in "${CHANGED_RELPATHS[@]+"${CHANGED_RELPATHS[@]}"}"; do
  topdir="${rel%%/*}"
  if ! name_in "$topdir" "${NAMES[@]}" && ! name_in "$topdir" "${PRE_EXISTING_TOPDIRS[@]+"${PRE_EXISTING_TOPDIRS[@]}"}"; then
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

CHANGED_TOPDIRS=()
for rel in "${CHANGED_RELPATHS[@]+"${CHANGED_RELPATHS[@]}"}"; do
  topdir="${rel%%/*}"
  if ! name_in "$topdir" "${CHANGED_TOPDIRS[@]+"${CHANGED_TOPDIRS[@]}"}"; then
    CHANGED_TOPDIRS+=("$topdir")
  fi
done

# Refuse to run any destructive rm -rf through a symlink anywhere above the
# target path, no matter how that path got classified above. Defense in
# depth for N1: even if the topdir-level symlink skip below has a gap, this
# still catches it before anything is deleted.
path_has_symlink_ancestor() {
  local path="$1" dir
  dir=$(dirname -- "$path")
  while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ "$dir" != "skills" ]; do
    if [ -L "$dir" ]; then
      return 0
    fi
    dir=$(dirname -- "$dir")
  done
  return 1
}

REVERTED_SUMMARY=()
for topdir in "${CHANGED_TOPDIRS[@]+"${CHANGED_TOPDIRS[@]}"}"; do
  if name_in "$topdir" "${NAMES[@]}"; then
    continue
  fi
  if name_in "$topdir" "${PRE_EXISTING_TOPDIRS[@]+"${PRE_EXISTING_TOPDIRS[@]}"}"; then
    # If this topdir was itself a symlink before the CLI ran, restoring that
    # symlink fully resolves its identity. Nothing "inside" it — reachable
    # only by walking through the restored symlink — is safe for this
    # script to touch, so skip every other changed path under this topdir
    # entirely rather than processing them against the backup (N1).
    backup_topdir_path="$BACKUP_DIR/skills-before/$topdir"
    if [ -L "$backup_topdir_path" ]; then
      live_topdir_path="skills/$topdir"
      rm -rf "$live_topdir_path"
      cp -a "$backup_topdir_path" "$live_topdir_path"
      REVERTED_SUMMARY+=("unrequested overwrite of existing skill '$topdir': reverted (restored symlink)")
      continue
    fi

    # Revert exactly the paths that changed under this topdir — never the
    # whole directory. A path present in the backup gets copied back
    # (cp -a overwrites a now-mismatched type, e.g. a symlink replaced by a
    # real directory, cleanly). A path absent from the backup was a pure
    # addition under an existing topdir, so it's removed on its own.
    for rel in "${CHANGED_RELPATHS[@]}"; do
      case "$rel" in
        "$topdir"/* | "$topdir") ;;
        *) continue ;;
      esac
      backup_path="$BACKUP_DIR/skills-before/$rel"
      live_path="skills/$rel"
      if path_has_symlink_ancestor "$live_path"; then
        echo "WARNING: skipping '$live_path' — a parent directory is a symlink; refusing to operate through it." >&2
        continue
      fi
      if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
        rm -rf "$live_path"
        mkdir -p "$(dirname "$live_path")"
        cp -a "$backup_path" "$live_path"
      else
        rm -rf "$live_path"
      fi
    done
    # A pure addition can leave behind a now-empty directory (e.g. a new
    # agents/ subfolder whose only file we just removed). Clean those up
    # too, bottom-up, but only ones that are actually empty — never the
    # topdir itself, and never a path that still holds restored content.
    if [ -d "skills/$topdir" ] && [ ! -L "skills/$topdir" ]; then
      find "skills/$topdir" -mindepth 1 -depth -type d -empty -delete
    fi
    REVERTED_SUMMARY+=("unrequested overwrite of existing skill '$topdir': reverted")
  else
    rm -rf "skills/$topdir"
    REVERTED_SUMMARY+=("unrequested new skill '$topdir': removed")
  fi
done

echo "Requested skills confirmed present:"
for n in "${NAMES[@]}"; do
  if [ -d "skills/$n" ]; then
    echo "  - $n"
  else
    echo "  - $n (MISSING — the install may not have actually included it)"
  fi
done

if [ "${#REVERTED_SUMMARY[@]}" -gt 0 ]; then
  echo "Cleaned up drift beyond the request:"
  printf '  - %s\n' "${REVERTED_SUMMARY[@]}"
fi

exit 0
