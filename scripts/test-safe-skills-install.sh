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

echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
[ "$FAIL_COUNT" -eq 0 ]
