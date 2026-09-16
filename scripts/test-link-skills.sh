#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_not_symlink() {
  local path="$1"
  [ ! -L "$path" ] || fail "expected $path not to be a symlink"
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"
  [ -L "$path" ] || fail "expected $path to be a symlink"
  [ "$(readlink "$path")" = "$expected" ] ||
    fail "expected $path to point to $expected"
}

assert_file_content() {
  local path="$1"
  local expected="$2"
  [ -f "$path" ] || fail "expected $path to be a file"
  [ "$(sed -n '1p' "$path")" = "$expected" ] ||
    fail "expected $path to contain $expected"
}

FIXTURE_REPO="$TEST_ROOT/repo"
FAKE_HOME="$TEST_ROOT/home"
FAKE_CODEX_HOME="$TEST_ROOT/codex"
mkdir -p \
  "$FIXTURE_REPO/scripts" \
  "$FIXTURE_REPO/skills/engineering/active" \
  "$FIXTURE_REPO/skills/engineering/file-skill" \
  "$FIXTURE_REPO/skills/engineering/dir-skill" \
  "$FIXTURE_REPO/skills/misc/shelved" \
  "$FIXTURE_REPO/skills/deprecated/retired" \
  "$TEST_ROOT/external/active" \
  "$FAKE_HOME/.claude/skills" \
  "$FAKE_HOME/.agents/skills" \
  "$FAKE_CODEX_HOME/skills"
cp "$ROOT/scripts/link-skills.sh" "$FIXTURE_REPO/scripts/link-skills.sh"
touch "$FIXTURE_REPO/skills/engineering/active/SKILL.md"
touch "$FIXTURE_REPO/skills/engineering/file-skill/SKILL.md"
touch "$FIXTURE_REPO/skills/engineering/dir-skill/SKILL.md"
touch "$FIXTURE_REPO/skills/misc/shelved/SKILL.md"
touch "$FIXTURE_REPO/skills/deprecated/retired/SKILL.md"
ln -s "$FIXTURE_REPO" "$TEST_ROOT/repo-alias"
ln -s "$TEST_ROOT/external/missing" "$TEST_ROOT/external/intermediate"

destinations=(
  "$FAKE_HOME/.claude/skills"
  "$FAKE_CODEX_HOME/skills"
  "$FAKE_HOME/.agents/skills"
)

for destination in "${destinations[@]}"; do
  ln -s \
    "$FIXTURE_REPO/skills/engineering/renamed-away" \
    "$destination/renamed-away"
  ln -s "$FIXTURE_REPO/skills/misc/shelved" "$destination/shelved"
  ln -s "$FIXTURE_REPO/skills/deprecated/retired" "$destination/retired"
  ln -s "$TEST_ROOT/external/active" "$destination/active"
  ln -s "$TEST_ROOT/external/missing" "$destination/external-missing"
  ln -s "$TEST_ROOT/external/intermediate" "$destination/external-chain"
  ln -s \
    "$FIXTURE_REPO/skills/engineering/system-gone" \
    "$destination/.system"
  case "$destination" in
    "$FAKE_CODEX_HOME/skills") relative_repo="../../repo" ;;
    *) relative_repo="../../../repo" ;;
  esac
  ln -s \
    "$relative_repo/skills/engineering/relative-gone" \
    "$destination/relative-gone"
  ln -s \
    "$TEST_ROOT/repo-alias/skills/engineering/alias-gone" \
    "$destination/alias-gone"
  echo "owned file" > "$destination/file-skill"
  mkdir "$destination/dir-skill"
  echo "owned directory" > "$destination/dir-skill/sentinel"
done

output="$(HOME="$FAKE_HOME" CODEX_HOME="$FAKE_CODEX_HOME" \
  bash "$FIXTURE_REPO/scripts/link-skills.sh")"

for destination in "${destinations[@]}"; do
  assert_not_symlink "$destination/renamed-away"
  assert_not_symlink "$destination/shelved"
  assert_not_symlink "$destination/retired"
  assert_not_symlink "$destination/relative-gone"
  assert_not_symlink "$destination/alias-gone"
  assert_symlink_target "$destination/active" "$TEST_ROOT/external/active"
  assert_symlink_target \
    "$destination/external-missing" \
    "$TEST_ROOT/external/missing"
  assert_symlink_target \
    "$destination/external-chain" \
    "$TEST_ROOT/external/intermediate"
  assert_symlink_target \
    "$destination/.system" \
    "$FIXTURE_REPO/skills/engineering/system-gone"
  [ ! -L "$destination/file-skill" ] ||
    fail "expected $destination/file-skill not to be replaced"
  assert_file_content "$destination/file-skill" "owned file"
  [ ! -L "$destination/dir-skill" ] ||
    fail "expected $destination/dir-skill not to be replaced"
  assert_file_content "$destination/dir-skill/sentinel" "owned directory"
done

case "$output" in
  *"removed renamed-away"*) ;;
  *) fail "expected removal to be reported" ;;
esac

case "$output" in
  *"removed shelved"*) ;;
  *) fail "expected the misc link removal to be reported" ;;
esac
case "$output" in
  *"removed retired"*) ;;
  *) fail "expected the deprecated link removal to be reported" ;;
esac

IDEMPOTENT_ROOT="$TEST_ROOT/idempotent"
IDEMPOTENT_REPO="$IDEMPOTENT_ROOT/repo"
IDEMPOTENT_HOME="$IDEMPOTENT_ROOT/home"
IDEMPOTENT_CODEX_HOME="$IDEMPOTENT_ROOT/codex"
mkdir -p \
  "$IDEMPOTENT_REPO/scripts" \
  "$IDEMPOTENT_REPO/skills/engineering/fresh"
cp "$ROOT/scripts/link-skills.sh" "$IDEMPOTENT_REPO/scripts/link-skills.sh"
touch "$IDEMPOTENT_REPO/skills/engineering/fresh/SKILL.md"

first_run="$(HOME="$IDEMPOTENT_HOME" CODEX_HOME="$IDEMPOTENT_CODEX_HOME" \
  bash "$IDEMPOTENT_REPO/scripts/link-skills.sh" 2>&1)"
case "$first_run" in
  *"linked fresh"*) ;;
  *) fail "expected the first run to report a linked skill" ;;
esac

second_run="$(HOME="$IDEMPOTENT_HOME" CODEX_HOME="$IDEMPOTENT_CODEX_HOME" \
  bash "$IDEMPOTENT_REPO/scripts/link-skills.sh" 2>&1)"
[ -z "$second_run" ] || fail "expected the second run to produce no output"

echo "PASS: link-skills removes dangling and demoted links into this repo"
echo "PASS: link-skills leaves external links and .system untouched"
echo "PASS: link-skills leaves real files and directories untouched"
echo "PASS: link-skills is a no-op on the second run"
