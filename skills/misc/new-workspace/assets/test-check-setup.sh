#!/usr/bin/env bash
# Hermetic test suite for check-setup.sh.
# A throwaway parent directory holding a workspace and fake member repos, a fake
# home with a .claude.json, and stub `gh` and `claude` binaries on PATH.
# Usage: test-check-setup.sh
set -uo pipefail
unset CDPATH   # an exported CDPATH makes `cd` echo its path and corrupts $( ) captures

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$here/check-setup.sh"
pass=0
fail=0

setup() {
  ROOT="$(mktemp -d)"
  ROOT="$(cd "$ROOT" && pwd -P)"
  PARENT="$ROOT/code"
  WS="$PARENT/demo-workspace"
  BIN="$ROOT/bin"
  mkdir -p "$WS/scripts" "$WS/.claude" "$ROOT/home" "$BIN" "$PARENT/core-a"
  cp "$SCRIPT" "$WS/scripts/check-setup.sh"
  chmod +x "$WS/scripts/check-setup.sh"
  git -C "$WS" init -q
  printf '{"repos":[{"name":"demo-workspace","tier":"core"},{"name":"core-a","tier":"core"},{"name":"adj-b","tier":"adjacent"}]}\n' > "$WS/repos.json"
  settings '"../demo-workspace-wt","../core-a","../core-a-wt","../adj-b","../adj-b-wt"'
  trust true
  gh_auth 0
  printf '#!/bin/sh\nexit 0\n' > "$BIN/claude"; chmod +x "$BIN/claude"
}

teardown() { [ -n "${ROOT:-}" ] && rm -rf "$ROOT"; ROOT=""; }

# settings <json list body>: the workspace's additionalDirectories.
settings() { printf '{"permissions":{"additionalDirectories":[%s]}}\n' "$1" > "$WS/.claude/settings.json"; }

# trust <true|false|none>: the workspace's entry in the fake ~/.claude.json.
trust() {
  case "$1" in
    none) printf '{"projects":{}}\n' > "$ROOT/home/.claude.json" ;;
    *) printf '{"projects":{"%s":{"hasTrustDialogAccepted":%s}}}\n' "$WS" "$1" > "$ROOT/home/.claude.json" ;;
  esac
}

# gh_auth <exit code>: what `gh auth status` returns.
gh_auth() { printf '#!/bin/sh\n[ "$1 $2" = "auth status" ] && exit %s\nexit 0\n' "$1" > "$BIN/gh"; chmod +x "$BIN/gh"; }

run_check() {
  OUT="$(HOME="$ROOT/home" PATH="$BIN:$PATH" "$WS/scripts/check-setup.sh" "$@" 2>&1)"
  RC=$?
  return 0
}

assert_contains() {
  case "$OUT" in
    *"$2"*) pass=$((pass + 1)); printf '  ok   %s\n' "$1" ;;
    *) fail=$((fail + 1)); printf '  FAIL %s\n       expected to contain: %s\n       got:\n%s\n' "$1" "$2" "$OUT" ;;
  esac
}

assert_not_contains() {
  case "$OUT" in
    *"$2"*) fail=$((fail + 1)); printf '  FAIL %s\n       expected NOT to contain: %s\n       got:\n%s\n' "$1" "$2" "$OUT" ;;
    *) pass=$((pass + 1)); printf '  ok   %s\n' "$1" ;;
  esac
}

assert_rc() {
  if [ "$RC" -eq "$2" ]; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"
  else fail=$((fail + 1)); printf '  FAIL %s\n       expected exit %s, got %s\n%s\n' "$1" "$2" "$RC" "$OUT"; fi
}

t() { printf '%s\n' "$1"; setup; "$2"; teardown; }

ready() {
  run_check
  assert_rc "a complete setup exits 0" 0
  assert_contains "and says so" "setup: ready"
  assert_not_contains "with nothing failed" "FAIL"
}

gh_not_signed_in() {
  gh_auth 1
  run_check
  assert_rc "gh not signed in exits 1" 1
  assert_contains "and names the fix" "gh auth login"
}

core_repo_missing() {
  rmdir "$PARENT/core-a"
  run_check
  assert_rc "a missing core repo exits 1" 1
  assert_contains "and names it" "core-a"
  assert_contains "and the fix" "sync-repos.sh"
}

adjacent_repo_missing_is_fine() {
  run_check
  assert_rc "a missing adjacent repo still exits 0" 0
  assert_contains "and is warned" "warn  adj-b"
}

no_self_row() {
  printf '{"repos":[{"name":"core-a","tier":"core"}]}\n' > "$WS/repos.json"
  settings '"../demo-workspace-wt","../core-a","../core-a-wt"'
  run_check
  assert_rc "a workspace that does not list itself still exits 0" 0
}

settings_missing() {
  rm "$WS/.claude/settings.json"
  run_check
  assert_rc "no settings.json exits 1" 1
  assert_contains "and says why it matters" "no session can read the member repos"
}

settings_invalid() {
  printf '{ not json\n' > "$WS/.claude/settings.json"
  run_check
  assert_rc "an unparseable settings.json exits 1" 1
  assert_contains "and says so" "not valid JSON"
}

settings_lacks_a_repo() {
  settings '"../demo-workspace-wt","../core-a","../adj-b","../adj-b-wt"'
  run_check
  assert_rc "a repo's -wt missing from settings exits 1" 1
  assert_contains "and names it" "../core-a-wt is expected"
}

settings_lacks_own_wt() {
  settings '"../core-a","../core-a-wt","../adj-b","../adj-b-wt"'
  run_check
  assert_rc "the workspace's own -wt missing exits 1" 1
  assert_contains "and names it" "../demo-workspace-wt is expected"
}

settings_has_extra() {
  settings '"../demo-workspace-wt","../core-a","../core-a-wt","../adj-b","../adj-b-wt","../stray"'
  run_check
  assert_rc "an entry repos.json does not claim exits 1" 1
  assert_contains "and names it" "../stray is in"
}

untrusted_workspace() {
  trust false
  run_check
  assert_rc "an untrusted workspace exits 1" 1
  assert_contains "and says why it matters" "trust"
}

never_opened() {
  trust none
  run_check
  assert_rc "a workspace never opened in claude exits 1" 1
  assert_contains "and names the fix" "trust prompt"
}

trusted_above() {
  printf '{"projects":{"%s":{"hasTrustDialogAccepted":true}}}\n' "$PARENT" > "$ROOT/home/.claude.json"
  run_check
  assert_rc "trust accepted on a directory above the workspace exits 0" 0
}

from_a_worktree() {
  git -C "$WS" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$WS" worktree add -q "$PARENT/demo-workspace-wt/x" -b x
  mkdir -p "$PARENT/demo-workspace-wt/x/scripts" "$PARENT/demo-workspace-wt/x/.claude"
  cp "$SCRIPT" "$PARENT/demo-workspace-wt/x/scripts/"
  cp "$WS/repos.json" "$PARENT/demo-workspace-wt/x/repos.json"
  cp "$WS/.claude/settings.json" "$PARENT/demo-workspace-wt/x/.claude/settings.json"
  OUT="$(HOME="$ROOT/home" PATH="$BIN:$PATH" "$PARENT/demo-workspace-wt/x/scripts/check-setup.sh" 2>&1)"; RC=$?
  assert_rc "run from a worktree, repos and trust resolve against the primary checkout" 0
}

no_manifest() {
  rm "$WS/repos.json"
  run_check
  assert_rc "no repos.json exits 2, could not check" 2
}

help_is_the_header() {
  run_check --help
  assert_rc "--help exits 0" 0
  assert_contains "and prints the header" "Check that this machine"
  assert_not_contains "and stops before the code" "set -uo"
}

settings_only_ignores_the_machine() {
  rmdir "$PARENT/core-a"; trust none; gh_auth 1
  run_check --settings-only
  assert_rc "--settings-only passes with no clones, no trust and no gh sign-in" 0
  assert_contains "and says what it checked" "settings: in sync"
}

settings_only_catches_drift() {
  settings '"../demo-workspace-wt","../core-a"'
  run_check --settings-only
  assert_rc "--settings-only still fails on drift" 1
  assert_contains "and names the entry" "../core-a-wt is expected"
}

t "ready" ready
t "gh not signed in" gh_not_signed_in
t "core repo missing" core_repo_missing
t "adjacent repo missing" adjacent_repo_missing_is_fine
t "no self row" no_self_row
t "settings missing" settings_missing
t "settings invalid" settings_invalid
t "settings lacks a repo" settings_lacks_a_repo
t "settings lacks own -wt" settings_lacks_own_wt
t "settings has an extra entry" settings_has_extra
t "untrusted workspace" untrusted_workspace
t "never opened" never_opened
t "trusted above" trusted_above
t "from a worktree" from_a_worktree
t "no manifest" no_manifest
t "--help" help_is_the_header
t "--settings-only ignores the machine" settings_only_ignores_the_machine
t "--settings-only catches drift" settings_only_catches_drift

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
