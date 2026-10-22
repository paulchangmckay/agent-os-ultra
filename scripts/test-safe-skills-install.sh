#!/usr/bin/env bash
# Behavioral tests for scripts/safe-skills-install.sh. No existing shell
# test framework in this repo — plain bash assertions, PASS/FAIL per case.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$SCRIPT_DIR/safe-skills-install.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Builds a disposable git fixture repo with a skills/ dir and returns its
# path on stdout. Each test gets its own fixture.
make_fixture() {
  local dir
  dir=$(mktemp -d)
  (
    cd "$dir" || exit
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p skills
    touch skills/.gitkeep
    git add -A
    git commit -q -m "init"
  )
  echo "$dir"
}

cleanup_fixture() {
  rm -rf "$1"
}

test_happy_path() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates a CLI that correctly installs only the requested skills.
shift  # repo arg
while [ "$#" -gt 0 ] && [ "$1" != "--global" ]; do
  mkdir -p "skills/$1"
  echo "content" > "skills/$1/SKILL.md"
  shift
done
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ] && echo "$output" | grep -q "wanted-skill"; then
    pass "happy path: exits 0 and reports the requested skill present"
  else
    fail "happy path: exit=$exit_code output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_happy_path

test_concurrent_commit_aborts() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates a concurrent session: installs the requested skill AND commits
# something, so HEAD moves during the run.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
git add -A
git commit -q -m "concurrent session's own commit"
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qi "concurrent\|ABORTED"; then
    pass "concurrent commit: aborts non-zero without auto-reverting"
  else
    fail "concurrent commit: exit=$exit_code output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_concurrent_commit_aborts

test_unexpected_nesting_aborts() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates a future CLI version that stops flattening category dirs:
# installs the requested skill at the TOP level fine, but also drops an
# unrelated skill nested two levels deep under an unrecognized category name.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
mkdir -p "skills/some-category/some-other-skill"
echo "content" > "skills/some-category/some-other-skill/SKILL.md"
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qi "nested\|ABORTED"; then
    pass "unexpected nesting: aborts non-zero without auto-reverting"
  else
    fail "unexpected nesting: exit=$exit_code output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_unexpected_nesting_aborts

test_pre_existing_untracked_file_is_left_alone() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  # A skill someone is drafting by hand — untracked, unrelated to this
  # run's request. Must survive untouched: the delta is computed against
  # a baseline snapshot, not a "working tree must be clean" precondition.
  mkdir -p "$fixture/skills/draft-in-progress"
  echo "someone's draft" > "$fixture/skills/draft-in-progress/SKILL.md"

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  local content
  content=$(cat "$fixture/skills/draft-in-progress/SKILL.md")

  if [ "$content" = "someone's draft" ] && [ -d "$fixture/skills/wanted-skill" ]; then
    pass "pre-existing untracked file: left alone, not mistaken for CLI drift"
  else
    fail "pre-existing untracked file: content=$content output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_pre_existing_untracked_file_is_left_alone

test_over_install_is_reverted() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates the real occurrence-2 bug: installs the requested skill plus
# an unrequested extra one.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
mkdir -p skills/unwanted-extra
echo "content" > skills/unwanted-extra/SKILL.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ] && [ ! -d "$fixture/skills/unwanted-extra" ] && [ -d "$fixture/skills/wanted-skill" ] && echo "$output" | grep -q "unwanted-extra"; then
    pass "over-install: exits 0, unrequested new skill removed, requested skill kept"
  else
    fail "over-install: exit=$exit_code output=$output; unwanted-extra exists=$([ -d "$fixture/skills/unwanted-extra" ] && echo yes || echo no)"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_overwrite_of_existing_skill_is_reverted() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    mkdir -p skills/existing-skill
    echo "original" > skills/existing-skill/SKILL.md
    git add -A
    git commit -q -m "add existing-skill"
  )
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates the real occurrence-2 bug: installs the requested skill, but
# ALSO overwrites an already-installed, unrequested skill.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
echo "overwritten" > skills/existing-skill/SKILL.md
mkdir -p skills/existing-skill/agents
echo "new" > skills/existing-skill/agents/openai.yaml
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?
  local content
  content=$(cat "$fixture/skills/existing-skill/SKILL.md")

  if [ "$exit_code" -eq 0 ] && [ "$content" = "original" ] && [ ! -e "$fixture/skills/existing-skill/agents" ] && echo "$output" | grep -q "existing-skill"; then
    pass "overwrite of existing skill: exits 0, reverted to original, stray agents/ removed"
  else
    fail "overwrite of existing skill: exit=$exit_code content=$content output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_over_install_is_reverted
test_overwrite_of_existing_skill_is_reverted

test_empty_skills_dir_no_crash() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  # Remove the .gitkeep to simulate a truly empty skills directory — this
  # triggers the PRE_EXISTING_TOPDIRS empty-array expansion bug if unguarded.
  (
    cd "$fixture" || exit
    rm skills/.gitkeep
    git add -A
    git commit -q -m "remove gitkeep"
  )

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Create the requested skill plus an extra unrequested one, which forces the
# code to expand PRE_EXISTING_TOPDIRS (which is empty) while checking if the
# unrequested directory should be cleaned up.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
mkdir -p skills/unwanted-extra
echo "content" > skills/unwanted-extra/SKILL.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo new-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 0 ] && [ ! -d "$fixture/skills/unwanted-extra" ] && [ -d "$fixture/skills/new-skill" ] && echo "$output" | grep -q "unwanted-extra"; then
    pass "empty skills directory: exits 0, unrequested new skill removed, requested skill kept (exercises PRE_EXISTING_TOPDIRS expansion)"
  else
    fail "empty skills directory: exit=$exit_code output=$output; unwanted-extra exists=$([ -d "$fixture/skills/unwanted-extra" ] && echo yes || echo no); new-skill exists=$([ -d "$fixture/skills/new-skill" ] && echo yes || echo no)"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_empty_skills_dir_no_crash

test_already_dirty_file_untouched_by_cli_survives() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    mkdir -p skills/existing-skill
    echo "original" > skills/existing-skill/SKILL.md
    git add -A
    git commit -q -m "add existing-skill"
    # The user's own uncommitted edit, made before this run and unrelated to
    # it. The CLI below never touches this file. Reverting it anyway (as the
    # old git-checkout-based mechanism did, resetting every tracked file in
    # the directory back to the commit) would destroy real work the script
    # had no business touching — that was the C1 bug. The snapshot-based
    # mechanism must leave it exactly as the user left it.
    echo "already dirty before this run" > skills/existing-skill/SKILL.md
  )
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Installs the requested skill plus an unrequested extra under
# existing-skill/, but never touches existing-skill/SKILL.md itself.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
mkdir -p skills/existing-skill/extra
echo "unrequested addition" > skills/existing-skill/extra/notes.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  local content
  content=$(cat "$fixture/skills/existing-skill/SKILL.md")

  if [ "$content" = "already dirty before this run" ] && [ ! -e "$fixture/skills/existing-skill/extra" ]; then
    pass "already-dirty file untouched by CLI: survives; unrequested addition elsewhere in the dir still reverted"
  else
    fail "already-dirty file untouched by CLI: content=$content output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_already_dirty_file_untouched_by_cli_survives

test_untracked_file_beside_a_cli_touched_file_survives() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    mkdir -p skills/existing-skill
    echo "original" > skills/existing-skill/SKILL.md
    git add -A
    git commit -q -m "add existing-skill"
  )
  # Never committed, never touched by the CLI below — a draft sitting in
  # the same directory as a file the CLI DOES overwrite.
  echo "scratch notes" > "$fixture/skills/existing-skill/NOTES.md"

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
echo "overwritten by the flaky CLI" > skills/existing-skill/SKILL.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  local notes skill
  notes=$(cat "$fixture/skills/existing-skill/NOTES.md")
  skill=$(cat "$fixture/skills/existing-skill/SKILL.md")

  if [ "$notes" = "scratch notes" ] && [ "$skill" = "original" ]; then
    pass "untracked file beside a CLI-touched file: survives untouched; touched file still reverted"
  else
    fail "untracked file beside CLI-touched file: notes=$notes skill=$skill output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_untracked_file_beside_a_cli_touched_file_survives

test_untracked_skill_dir_partially_modified_survives_except_the_change() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  # An entire skill directory that was never committed at all — e.g. a
  # draft someone is assembling by hand. The CLI below modifies one file in
  # it (without being asked) but leaves another alone.
  mkdir -p "$fixture/skills/untracked-skill"
  echo "note A" > "$fixture/skills/untracked-skill/a.md"
  echo "note B" > "$fixture/skills/untracked-skill/b.md"

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
echo "overwritten" > skills/untracked-skill/a.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  local a b
  a=$(cat "$fixture/skills/untracked-skill/a.md")
  b=$(cat "$fixture/skills/untracked-skill/b.md")

  if [ "$a" = "note A" ] && [ "$b" = "note B" ] && [ -d "$fixture/skills/wanted-skill" ]; then
    pass "untracked skill dir partially modified: reverted file restored, untouched sibling file survives"
  else
    fail "untracked skill dir partially modified: a=$a b=$b output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_untracked_skill_dir_partially_modified_survives_except_the_change

test_symlinked_skill_dir_replaced_is_reverted_to_symlink() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    mkdir -p other-place/real-skill-target
    echo "target content" > other-place/real-skill-target/SKILL.md
    ln -s ../other-place/real-skill-target skills/linked-skill
    git add -A
    git commit -q -m "add symlinked skill, mimicking skills/brainstorming -> ../superpowers/..."
  )

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Simulates a future CLI version that replaces a symlinked topdir with a
# real directory of the same name, without being asked.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
rm -rf skills/linked-skill
mkdir -p skills/linked-skill
echo "overwritten by the flaky CLI" > skills/linked-skill/SKILL.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)

  # N1 regression check: a prior fix correctly restored the symlink itself
  # but then processed "linked-skill/SKILL.md" as a separate changed path,
  # which — resolved through the now-restored symlink — pointed at the REAL
  # target file outside any backup and got rm -rf'd. The symlink-is-restored
  # assertion alone passed even with that bug present, which is exactly how
  # it slipped through last time; the target file's content must be checked
  # too.
  local target_content
  target_content=$(cat "$fixture/other-place/real-skill-target/SKILL.md" 2>/dev/null)

  if [ -L "$fixture/skills/linked-skill" ] && [ "$(readlink "$fixture/skills/linked-skill")" = "../other-place/real-skill-target" ] && [ -d "$fixture/skills/wanted-skill" ] && [ "$target_content" = "target content" ]; then
    pass "symlinked skill dir replaced by a real dir: reverted back to a symlink, symlink's real target file survives untouched"
  else
    fail "symlinked skill dir replaced: is_symlink=$([ -L "$fixture/skills/linked-skill" ] && echo yes || echo no) target_content=$target_content output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_symlinked_skill_dir_replaced_is_reverted_to_symlink

test_plain_top_level_file_touched_by_cli_survives() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    # A plain regular file directly under skills/ — not a skill directory
    # or a symlink. PRE_EXISTING_TOPDIRS used to be built from a `find`
    # filtered to -type d -o -type l, so a file here was invisible to it
    # and got misclassified as "an entirely new unrequested skill" the
    # moment the CLI touched it (N2).
    echo "original readme" > skills/README.md
    git add -A
    git commit -q -m "add top-level README.md"
  )

  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Installs the requested skill, and also rewrites an unrequested top-level
# plain file while it's at it.
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
echo "overwritten by the flaky CLI" > skills/README.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  local content
  content=$(cat "$fixture/skills/README.md" 2>/dev/null)

  if [ "$content" = "original readme" ] && [ -d "$fixture/skills/wanted-skill" ]; then
    pass "plain top-level file touched by CLI: recognized as pre-existing, reverted rather than deleted as a new skill"
  else
    fail "plain top-level file touched by CLI: content=$content output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_plain_top_level_file_touched_by_cli_survives

test_cli_failure_is_reported_and_propagated() {
  local fixture fake_cli output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
echo "simulated network error" >&2
exit 7
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -eq 7 ] && echo "$output" | grep -qi "FAILED"; then
    pass "CLI failure: exit code propagated, reported as FAILED"
  else
    fail "CLI failure: exit=$exit_code output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_cli_failure_is_reported_and_propagated

test_full_occurrence_2_reproduction() {
  local fixture fake_cli output
  fixture=$(make_fixture)
  (
    cd "$fixture" || exit
    for s in grill-me grilling handoff; do
      mkdir -p "skills/$s"
      echo "original $s" > "skills/$s/SKILL.md"
    done
    git add -A
    git commit -q -m "pre-existing skills"
  )
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Reproduces occurrence 2: 3 names requested (passed as args), but the CLI
# installs those 3 PLUS 2 unrequested new skills, and overwrites 1 of the
# 3 pre-existing skills that wasn't even part of this request.
shift
for name in "$@"; do
  [ "$name" = "--global" ] && break
  mkdir -p "skills/$name"
  echo "content" > "skills/$name/SKILL.md"
done
mkdir -p skills/ask-matt skills/tdd
echo "content" > skills/ask-matt/SKILL.md
echo "content" > skills/tdd/SKILL.md
echo "overwritten by the flaky CLI" > skills/handoff/SKILL.md
exit 0
FAKECLI
  chmod +x "$fake_cli"

  output=$(cd "$fixture" && SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" mattpocock/skills claude-handoff pr git-guardrails-claude-code 2>&1)

  local ok=1
  [ -d "$fixture/skills/claude-handoff" ] || ok=0
  [ -d "$fixture/skills/pr" ] || ok=0
  [ -d "$fixture/skills/git-guardrails-claude-code" ] || ok=0
  [ -d "$fixture/skills/ask-matt" ] && ok=0
  [ -d "$fixture/skills/tdd" ] && ok=0
  [ "$(cat "$fixture/skills/handoff/SKILL.md")" = "original handoff" ] || ok=0

  if [ "$ok" -eq 1 ]; then
    pass "full occurrence-2 reproduction: requested kept, extras removed, overwritten pre-existing skill reverted"
  else
    fail "full occurrence-2 reproduction: output=$output"
  fi

  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_full_occurrence_2_reproduction

test_mktemp_failure_aborts_before_running_cli() {
  local fixture fake_cli fake_bin output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Should never run — the backup step (mktemp -d) is supposed to fail first
# and abort before the CLI is ever invoked (N4).
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
touch cli-ran-marker
exit 0
FAKECLI
  chmod +x "$fake_cli"

  fake_bin=$(mktemp -d)
  cat > "$fake_bin/mktemp" <<'FAKEMKTEMP'
#!/usr/bin/env bash
exit 1
FAKEMKTEMP
  chmod +x "$fake_bin/mktemp"

  output=$(cd "$fixture" && PATH="$fake_bin:$PATH" SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qi "mktemp" && [ ! -e "$fixture/cli-ran-marker" ]; then
    pass "mktemp failure: aborts non-zero before running the CLI"
  else
    fail "mktemp failure: exit=$exit_code output=$output cli_ran=$([ -e "$fixture/cli-ran-marker" ] && echo yes || echo no)"
  fi

  rm -rf "$fake_bin"
  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_mktemp_failure_aborts_before_running_cli

test_backup_cp_failure_aborts_before_running_cli() {
  local fixture fake_cli fake_bin output exit_code
  fixture=$(make_fixture)
  fake_cli=$(mktemp)
  cat > "$fake_cli" <<'FAKECLI'
#!/usr/bin/env bash
# Should never run — the backup step (cp -a skills ...) is supposed to fail
# first and abort before the CLI is ever invoked (N4).
shift
mkdir -p "skills/$1"
echo "content" > "skills/$1/SKILL.md"
touch cli-ran-marker
exit 0
FAKECLI
  chmod +x "$fake_cli"

  # A fake `cp` that always fails, standing in for a real backup failure
  # (disk full, permissions, etc.) without needing to actually induce one.
  fake_bin=$(mktemp -d)
  cat > "$fake_bin/cp" <<'FAKECP'
#!/usr/bin/env bash
exit 1
FAKECP
  chmod +x "$fake_bin/cp"

  output=$(cd "$fixture" && PATH="$fake_bin:$PATH" SAFE_SKILLS_INSTALL_CLI="$fake_cli" "$SUT" fake/repo wanted-skill 2>&1)
  exit_code=$?

  if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qi "back up\|backup" && [ ! -e "$fixture/cli-ran-marker" ]; then
    pass "backup cp failure: aborts non-zero before running the CLI"
  else
    fail "backup cp failure: exit=$exit_code output=$output cli_ran=$([ -e "$fixture/cli-ran-marker" ] && echo yes || echo no)"
  fi

  rm -rf "$fake_bin"
  cleanup_fixture "$fixture"
  rm -f "$fake_cli"
}

test_backup_cp_failure_aborts_before_running_cli

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
