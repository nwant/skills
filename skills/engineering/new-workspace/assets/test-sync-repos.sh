#!/usr/bin/env bash
# Hermetic test suite for sync-repos.sh.
# No network, no real gh, no real clones: fake bare remotes on disk, a stub gh
# on PATH, and a throwaway workspace containing a throwaway repos.json.
# Usage: scripts/test-sync-repos.sh
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$here/sync-repos.sh"
pass=0
fail=0

setup() {
  ROOT="$(mktemp -d)"
  export ROOT
  export WS_PARENT="$ROOT/parent"
  export FAKE_REMOTES="$ROOT/remotes"
  export GH_AUTH_OK=1
  mkdir -p "$WS_PARENT" "$FAKE_REMOTES" "$ROOT/bin" "$ROOT/ws/scripts" "$ROOT/seed"
  cp "$SCRIPT" "$ROOT/ws/scripts/sync-repos.sh"
  chmod +x "$ROOT/ws/scripts/sync-repos.sh"

  # Stub gh: only the two subcommands the script uses.
  cat > "$ROOT/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "auth status")
    if [ "${GH_AUTH_OK:-1}" = "1" ]; then exit 0; fi
    echo "gh: not logged in" >&2; exit 1 ;;
  "repo clone")
    slug="$3"; dest="$4"
    src="$FAKE_REMOTES/$(basename "$slug").git"
    if [ ! -d "$src" ]; then echo "gh: could not find $slug" >&2; exit 1; fi
    exec git clone --quiet "$src" "$dest" ;;
esac
echo "stub gh: unhandled invocation: $*" >&2
exit 99
STUB
  chmod +x "$ROOT/bin/gh"
  PATH="$ROOT/bin:$PATH"
  export PATH
}

teardown() {
  [ -n "${ROOT:-}" ] && rm -rf "$ROOT"
  ROOT=""
}

# mk_remote <name>: a bare remote on main with one commit, plus a seed worktree.
mk_remote() {
  local n="$1" r="$FAKE_REMOTES/$1.git" w="$ROOT/seed/$1"
  git init -q --bare "$r"
  git init -q "$w"
  git -C "$w" config user.email test@example.com
  git -C "$w" config user.name Test
  git -C "$w" symbolic-ref HEAD refs/heads/main
  echo one > "$w/file"
  git -C "$w" add file
  git -C "$w" commit -qm "one"
  git -C "$w" remote add origin "$r"
  git -C "$w" push -q -u origin main
  git -C "$r" symbolic-ref HEAD refs/heads/main
}

# advance_remote <name> <n>: push n additional commits to the remote's main.
advance_remote() {
  local name="$1" count="$2" w="$ROOT/seed/$1" i=0
  while [ "$i" -lt "$count" ]; do
    i=$((i + 1))
    echo "extra $i" >> "$w/file"
    git -C "$w" commit -qam "extra $i"
  done
  git -C "$w" push -q origin main
}

# add_remote_file <name> <path> <contents>: commit and push one new tracked
# file to the remote's main. Distinct from advance_remote, which only ever
# appends to "file": tests that need a second tracked path, or an incoming
# commit that adds a path rather than editing one, use this.
add_remote_file() {
  local name="$1" path="$2" body="$3" w="$ROOT/seed/$1"
  printf '%s\n' "$body" > "$w/$path"
  git -C "$w" add "$path"
  git -C "$w" commit -qm "add $path"
  git -C "$w" push -q origin main
}

# write_manifest <json>: install a throwaway repos.json.
write_manifest() { printf '%s\n' "$1" > "$ROOT/ws/repos.json"; }

# run_sync [args...]: run the script, capturing combined output in OUT, exit in RC.
run_sync() {
  OUT="$("$ROOT/ws/scripts/sync-repos.sh" "$@" 2>&1)"
  RC=$?
  return 0
}

# mk_primary_with_worktree: a primary git repo plus one linked worktree, laid
# out the way this workspace actually is: <parent>/repo (primary) and
# <parent>/repo-wt/feature (linked worktree). Sets PRIMARY and WT_DIR. A
# parent-resolution bug that just took dirname(worktree) would land inside
# repo-wt/ (sibling of the worktree), not beside the primary checkout.
mk_primary_with_worktree() {
  PRIMARY="$ROOT/primary/repo"
  WT_DIR="$ROOT/primary/repo-wt/feature"
  mkdir -p "$PRIMARY"
  git init -q "$PRIMARY"
  git -C "$PRIMARY" config user.email test@example.com
  git -C "$PRIMARY" config user.name Test
  echo x > "$PRIMARY/seed"
  git -C "$PRIMARY" add seed
  git -C "$PRIMARY" commit -qm seed
  mkdir -p "$(dirname "$WT_DIR")"
  git -C "$PRIMARY" worktree add -q -b wt-feature "$WT_DIR" >/dev/null
}

assert_contains() {
  case "$OUT" in
    *"$2"*) pass=$((pass + 1)); printf '  ok   %s\n' "$1" ;;
    *) fail=$((fail + 1))
       printf '  FAIL %s\n       expected to contain: %s\n       got:\n%s\n' "$1" "$2" "$OUT" ;;
  esac
}

assert_not_contains() {
  case "$OUT" in
    *"$2"*) fail=$((fail + 1))
       printf '  FAIL %s\n       expected NOT to contain: %s\n       got:\n%s\n' "$1" "$2" "$OUT" ;;
    *) pass=$((pass + 1)); printf '  ok   %s\n' "$1" ;;
  esac
}

assert_rc() {
  if [ "$RC" = "$2" ]; then
    pass=$((pass + 1)); printf '  ok   %s\n' "$1"
  else
    fail=$((fail + 1))
    printf '  FAIL %s\n       expected exit %s, got %s\n       output:\n%s\n' "$1" "$2" "$RC" "$OUT"
  fi
}

report() {
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || exit 1
}

# ---------------------------------------------------------------- tests

test_preflight_gh_unauthenticated() {
  echo "test: preflight aborts when gh is unauthenticated"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  GH_AUTH_OK=0 run_sync
  assert_rc "exits 1" 1
  assert_contains "names the problem" "not authenticated"
  assert_contains "prints the fix" "gh auth login"
  assert_not_contains "does not clone anything" "cloned"
  teardown
}

test_preflight_missing_tool() {
  echo "test: preflight aborts when a required tool is missing"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  # Shadow jq with an empty PATH entry containing only git+bash essentials.
  mkdir -p "$ROOT/emptybin"
  OUT="$(PATH="$ROOT/emptybin:/usr/bin:/bin" "$ROOT/ws/scripts/sync-repos.sh" 2>&1)"
  RC=$?
  assert_rc "exits 1" 1
  assert_contains "names the missing tool" "missing required tool"
  teardown
}

test_help_flag() {
  echo "test: --help prints usage and exits 0"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  GH_AUTH_OK=0 run_sync --help
  assert_rc "exits 0" 0
  assert_contains "prints usage" "Usage: sync-repos.sh"
  assert_not_contains "does not leak the shebang preamble" "set -euo pipefail"
  teardown
}

test_unknown_flag() {
  echo "test: an unknown flag exits 2"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  GH_AUTH_OK=0 run_sync --bogus
  assert_rc "exits 2" 2
  teardown
}

test_print_shows_both_tiers() {
  echo "test: --print renders both tiers without needing gh auth"
  setup
  write_manifest '{"repos":[
    {"name":"repo-a","slug":"testorg/repo-a","tier":"core"},
    {"name":"repo-b","slug":"testorg/repo-b","tier":"adjacent"}
  ]}'
  # --all: this test asserts --print CAN render both tiers together; the
  # default-is-core-only behavior is covered separately by test_tier_selection.
  GH_AUTH_OK=0 run_sync --print --all
  assert_rc "exits 0 even unauthenticated" 0
  assert_contains "lists core repo" "repo-a"
  assert_contains "shows slug" "testorg/repo-a"
  assert_contains "lists adjacent repo in --print" "repo-b"
  # (No "performs no sync" assertion on the string "up to date" here: this
  # test runs with GH_AUTH_OK=0, so a regression that dropped --print's early
  # exit would abort at require_gh_auth before ever reaching a real sync,
  # already caught by "exits 0 even unauthenticated" above. Asserting the
  # absence of a string that only `ok()` ever emits, in a run that could never
  # reach `ok()` either way, has zero discriminating power.)
  teardown
}

test_local_override_wins() {
  echo "test: repos.local.json overrides by name and adds repos"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  printf '%s\n' '{"repos":[
    {"name":"repo-a","slug":"myfork/repo-a","tier":"core"},
    {"name":"repo-c","slug":"testorg/repo-c","tier":"core"}
  ]}' > "$ROOT/ws/repos.local.json"
  GH_AUTH_OK=0 run_sync --print
  assert_contains "override wins" "myfork/repo-a"
  assert_not_contains "overridden slug is gone" "testorg/repo-a"
  assert_contains "local-only repo appears" "repo-c"
  teardown
}

test_legacy_url_manifest_entries() {
  echo "test: legacy 'url' entries (ssh form, https form, derived name) resolve like slug entries"
  setup
  write_manifest '{"repos":[]}'
  # repos.local.json is where the README used to tell people to write `url`
  # entries: this covers the ssh form, the https form, and name-derivation
  # from the slug's last path segment, all in one manifest.
  printf '%s\n' '{"repos":[
    {"url":"git@github.com:testorg/repo-ssh.git","tier":"core"},
    {"url":"https://github.com/testorg/repo-https.git","tier":"core"},
    {"name":"repo-named","url":"https://github.com/testorg/repo-real-slug.git","tier":"core"}
  ]}' > "$ROOT/ws/repos.local.json"
  GH_AUTH_OK=0 run_sync --print
  assert_rc "exits 0" 0
  assert_contains "ssh-form url resolves to a slug" "testorg/repo-ssh"
  assert_contains "ssh-form name derives from the slug" "repo-ssh"
  assert_contains "https-form url resolves to a slug" "testorg/repo-https"
  assert_contains "https-form name derives from the slug" "repo-https"
  assert_contains "explicit name is kept over the derived one" "repo-named"
  assert_contains "explicit-name entry still carries its own slug" "testorg/repo-real-slug"
  teardown
}

test_tier_selection() {
  echo "test: default is core only; --all adds adjacent; names select explicitly"
  setup
  write_manifest '{"repos":[
    {"name":"repo-a","slug":"testorg/repo-a","tier":"core"},
    {"name":"repo-b","slug":"testorg/repo-b","tier":"adjacent"}
  ]}'
  # Selection is fully observable through --print, which performs no writes and
  # needs no gh auth, so this test needs no remotes and no clones.
  export GH_AUTH_OK=0

  run_sync --print
  assert_contains "core repo selected by default" "repo-a"
  assert_not_contains "adjacent repo excluded by default" "repo-b"

  run_sync --print --all
  assert_contains "--all includes adjacent" "repo-b"
  assert_contains "--all keeps core" "repo-a"

  run_sync --print repo-b
  assert_contains "named adjacent repo is selected" "repo-b"
  assert_not_contains "unnamed core repo is excluded" "repo-a"

  run_sync --print nope
  assert_rc "unknown name exits 2" 2
  assert_contains "unknown name is named" "unknown repo: nope"
  teardown
}

test_clone_and_idempotency() {
  echo "test: clones missing repos, then is idempotent"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a

  run_sync
  assert_rc "exits 0" 0
  assert_contains "reports the clone" "+ repo-a"
  assert_contains "names the destination" "$WS_PARENT/repo-a"
  if [ -f "$WS_PARENT/repo-a/file" ]; then
    pass=$((pass + 1)); printf '  ok   working tree materialised\n'
  else
    fail=$((fail + 1)); printf '  FAIL working tree materialised\n'
  fi

  run_sync
  assert_rc "second run exits 0" 0
  assert_contains "second run reports up to date" "✓ repo-a"
  assert_not_contains "second run does not re-clone" "+ repo-a"
  teardown
}

test_clone_failure_continues() {
  echo "test: a failed clone is reported, does not abort the run, and exits non-zero"
  setup
  # read_manifest's group_by(.name) sorts entries alphabetically by name, so
  # the TSV order sync_one actually sees is repo-0-missing THEN repo-a
  # (independent of write order below). Naming the failing repo so it sorts
  # first is what makes "repo-a still gets processed" prove continuation past
  # a failure, rather than merely reporting on whichever repo happens to run
  # last.
  write_manifest '{"repos":[
    {"name":"repo-0-missing","slug":"testorg/repo-0-missing","tier":"core"},
    {"name":"repo-a","slug":"testorg/repo-a","tier":"core"}
  ]}'
  mk_remote repo-a   # repo-0-missing deliberately has no fake remote

  run_sync
  assert_contains "earlier repo's failure is reported" "✗ repo-0-missing"
  assert_contains "later repo is still processed after the earlier failure" "+ repo-a"
  assert_rc "exits non-zero" 1
  assert_contains "summary counts the failure" "1 failed"
  teardown
}

test_empty_repo_does_not_abort_the_run() {
  echo "test: a repo with no commits (unborn HEAD) is reported, not a whole-run abort (case 2)"
  setup
  # Sort repo-0-empty before repo-z, matching the naming trick in
  # test_clone_failure_continues: the empty repo must be processed FIRST so a
  # bug that aborts the whole script (rather than isolating the problem to
  # one repo) would prevent repo-z from ever being reached, and summary from
  # ever printing.
  write_manifest '{"repos":[
    {"name":"repo-0-empty","slug":"testorg/repo-0-empty","tier":"core"},
    {"name":"repo-z","slug":"testorg/repo-z","tier":"core"}
  ]}'
  # A bare remote with NO commits at all: cloning it produces an unborn HEAD
  # (`branch --show-current` still reports the default branch name, but
  # `rev-parse HEAD` has nothing to resolve, exit 128, which `set -e` turns
  # into a whole-script abort if unguarded).
  git init -q --bare "$FAKE_REMOTES/repo-0-empty.git"
  git -C "$FAKE_REMOTES/repo-0-empty.git" symbolic-ref HEAD refs/heads/main
  mk_remote repo-z

  run_sync   # initial clone of both
  advance_remote repo-z 1

  run_sync
  assert_rc "exits 0, not aborted" 0
  assert_contains "the empty repo is reported" "repo-0-empty"
  assert_contains "names the reason" "no commits yet"
  assert_contains "repo-z is still processed after it" "↓ repo-z"
  assert_contains "summary still prints" "up to date"
  teardown
}

test_fast_forward_on_default_branch() {
  echo "test: clean checkout on default branch fast-forwards (case 2)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync                      # initial clone
  advance_remote repo-a 3
  run_sync
  assert_rc "exits 0" 0
  assert_contains "reports an update" "↓ repo-a"
  assert_contains "reports the commit count" "3 commits"
  teardown
}

test_dirty_on_default_branch_is_not_merged() {
  echo "test: tracked local modification on default branch is fetched only (case 3)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  # Dirty via a TRACKED edit to a file the incoming commit does not touch.
  # That combination is what carries discriminating power: advance_remote only
  # ever appends to "file", so `merge --ff-only` would carry a local edit to
  # "other" across without complaint. Drop the dirty guard and this run
  # fast-forwards cleanly and emits ↓ instead of !. (Two shapes lack that
  # power and must not be used here. A same-file conflicting edit: git's own
  # checkout protection refuses the merge anyway, with a message that also
  # says "not merged", so the assertions pass whether or not the guard
  # exists; the bug in an earlier version of this test. And an untracked
  # file: no longer gated at all, by design; see
  # test_untracked_only_does_not_block_fast_forward.)
  add_remote_file repo-a other keep
  run_sync                      # initial clone brings down both files
  echo local-edit > "$WS_PARENT/repo-a/other"
  advance_remote repo-a 1

  run_sync
  assert_contains "reports it" "! repo-a"
  assert_contains "names the reason" "uncommitted changes"
  # The assertion that actually catches a missing dirty guard: a regression
  # would fast-forward cleanly and emit the ↓ mark instead of !.
  assert_not_contains "does not report a fast-forward" "↓ repo-a"
  # (No "refusing to fetch" assertion here: case 3 never attempts the
  # refspec at all, so that fatal can never be reachable from this code
  # path regardless of any regression nearby, asserting its absence here
  # would have zero discriminating power. The equivalent, meaningful check
  # (that the raw fatal never leaks past case 4's own classification) is
  # covered by test_default_branch_checked_out_in_worktree_is_reported_distinctly.)
  if [ "$(cat "$WS_PARENT/repo-a/other")" = "local-edit" ] && \
     [ "$(cat "$WS_PARENT/repo-a/file")" = "one" ]; then
    pass=$((pass + 1)); printf '  ok   working tree undisturbed (local edit kept, no merge applied)\n'
  else
    fail=$((fail + 1)); printf '  FAIL working tree undisturbed (local edit kept, no merge applied)\n'
  fi
  teardown
}

test_untracked_only_does_not_block_fast_forward() {
  echo "test: untracked-only files do not hold back the fast-forward (case 2)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  # The inverse of the case-3 test above, and the reason the gate passes
  # --untracked-files=no: editor dirs, local CLAUDE.md notes and stray docs
  # must not pin a repo to a stale commit. The incoming commit touches only
  # "file", so nothing here is at risk.
  echo scratch > "$WS_PARENT/repo-a/untracked-local-file"
  advance_remote repo-a 2

  run_sync
  assert_rc "exits 0" 0
  assert_contains "fast-forwards anyway" "↓ repo-a"
  assert_contains "reports the commit count" "2 commits"
  assert_not_contains "does not withhold the merge" "uncommitted changes"
  if [ -f "$WS_PARENT/repo-a/untracked-local-file" ] && \
     [ "$(cat "$WS_PARENT/repo-a/untracked-local-file")" = "scratch" ]; then
    pass=$((pass + 1)); printf '  ok   untracked file survives the merge\n'
  else
    fail=$((fail + 1)); printf '  FAIL untracked file survives the merge\n'
  fi
  teardown
}

test_incoming_file_colliding_with_untracked_is_classified() {
  echo "test: an incoming file colliding with an untracked one is not called divergence"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  # The one way an untracked file still interacts with the merge, reachable
  # only because the gate no longer pre-empts it: the incoming commit adds
  # "newdoc", which already exists locally as untracked. git refuses on its
  # own (correctly, it would be overwritten), and the point of this test is
  # that the refusal is reported as such instead of being swept into the
  # "diverged" arm, which is what the pre-classification else-branch did.
  echo mine > "$WS_PARENT/repo-a/newdoc"
  add_remote_file repo-a newdoc theirs

  run_sync
  assert_contains "reports it" "! repo-a"
  assert_contains "names the untracked collision" "untracked"
  assert_not_contains "does not misreport divergence" "diverged"
  assert_not_contains "does not leak the raw git fatal" "error:"
  if [ "$(cat "$WS_PARENT/repo-a/newdoc")" = "mine" ]; then
    pass=$((pass + 1)); printf '  ok   local untracked file not clobbered\n'
  else
    fail=$((fail + 1)); printf '  FAIL local untracked file not clobbered\n'
  fi
  teardown
}

test_feature_branch_advances_default_branch() {
  echo "test: on a non-default branch, default branch fast-forwards (case 4)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  git -C "$WS_PARENT/repo-a" checkout -q -b feature/work
  echo "feature work" >> "$WS_PARENT/repo-a/file"
  git -C "$WS_PARENT/repo-a" config user.email test@example.com
  git -C "$WS_PARENT/repo-a" config user.name Test
  git -C "$WS_PARENT/repo-a" commit -qam "feature commit"
  advance_remote repo-a 2

  run_sync
  assert_contains "reports the branch" "on feature/work"
  assert_contains "reports the fast-forward" "fast-forwarded"
  local local_main remote_main
  local_main="$(git -C "$WS_PARENT/repo-a" rev-parse main)"
  remote_main="$(git -C "$FAKE_REMOTES/repo-a.git" rev-parse main)"
  if [ "$local_main" = "$remote_main" ]; then
    pass=$((pass + 1)); printf '  ok   local main advanced to remote main\n'
  else
    fail=$((fail + 1)); printf '  FAIL local main advanced to remote main\n'
  fi
  if [ "$(git -C "$WS_PARENT/repo-a" branch --show-current)" = "feature/work" ]; then
    pass=$((pass + 1)); printf '  ok   still on feature branch\n'
  else
    fail=$((fail + 1)); printf '  FAIL still on feature branch\n'
  fi
  teardown
}

test_diverged_default_branch_both_shapes() {
  echo "test: diverged default branch is reported in both shapes (cases 2 and 4)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  git -C "$WS_PARENT/repo-a" config user.email test@example.com
  git -C "$WS_PARENT/repo-a" config user.name Test
  echo "divergent" >> "$WS_PARENT/repo-a/file"
  git -C "$WS_PARENT/repo-a" commit -qam "local divergent commit"
  local divergent_sha
  divergent_sha="$(git -C "$WS_PARENT/repo-a" rev-parse main)"
  advance_remote repo-a 1

  # shape 1: diverged AND checked out (case 2, merge --ff-only refuses)
  run_sync
  assert_contains "diverged reported while checked out" "diverged"
  assert_rc "diverged is a warning, not a failure" 0
  # State, not just message: the divergent commit must still be there, and
  # main must not have moved to (or past) origin's line at all.
  if [ "$(git -C "$WS_PARENT/repo-a" rev-parse main)" = "$divergent_sha" ]; then
    pass=$((pass + 1)); printf '  ok   local main still at the divergent commit (not merged, not reset)\n'
  else
    fail=$((fail + 1)); printf '  FAIL local main still at the divergent commit (not merged, not reset)\n'
  fi

  # shape 2: diverged and NOT checked out (case 4, refspec refuses)
  git -C "$WS_PARENT/repo-a" checkout -q -b feature/other
  run_sync
  assert_contains "diverged reported from a feature branch" "diverged"
  assert_contains "still names the branch" "on feature/other"
  if [ "$(git -C "$WS_PARENT/repo-a" rev-parse main)" = "$divergent_sha" ]; then
    pass=$((pass + 1)); printf '  ok   local main still at the divergent commit from a feature branch too\n'
  else
    fail=$((fail + 1)); printf '  FAIL local main still at the divergent commit from a feature branch too\n'
  fi
  teardown
}

test_no_local_default_branch_is_not_created() {
  echo "test: case 4 must not create a missing local default branch (no branch create)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  git -C "$WS_PARENT/repo-a" checkout -q -b feature/work
  # Delete the local default branch entirely, plausible in a feature-branch-
  # only workflow, and exactly the condition under which the bare refspec
  # `origin main:main` is a fast-forward from nothing, so git would silently
  # create it if nothing guards against that.
  git -C "$WS_PARENT/repo-a" branch -D main >/dev/null
  advance_remote repo-a 1

  run_sync
  assert_contains "reports no local default branch" "no local main"
  assert_not_contains "does not report a fast-forward" "fast-forwarded"
  if git -C "$WS_PARENT/repo-a" rev-parse --verify --quiet refs/heads/main >/dev/null; then
    fail=$((fail + 1)); printf '  FAIL main was not created\n'
  else
    pass=$((pass + 1)); printf '  ok   main was not created\n'
  fi
  teardown
}

test_default_branch_checked_out_in_worktree_is_reported_distinctly() {
  echo "test: default branch checked out in a linked worktree is not mislabeled diverged (case 4)"
  setup
  write_manifest '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}'
  mk_remote repo-a
  run_sync
  # Move the primary clone off main so a linked worktree can check main out
  # (git worktree add refuses if main is already checked out in the primary).
  git -C "$WS_PARENT/repo-a" checkout -q -b feature/work
  git -C "$WS_PARENT/repo-a" worktree add -q "$ROOT/wt-main" main
  local premain
  premain="$(git -C "$WS_PARENT/repo-a" rev-parse main)"
  advance_remote repo-a 1

  run_sync
  assert_contains "identifies the worktree case" "checked out in another worktree"
  assert_not_contains "does not mislabel it as diverged" "diverged"
  # Would fail if the classification regressed to dumping the raw git fatal
  # instead of a friendly message: the fatal literally reads "...checked
  # out at '<path>'".
  assert_not_contains "does not leak the raw git fatal" "checked out at"
  if [ "$(git -C "$WS_PARENT/repo-a" rev-parse main)" = "$premain" ]; then
    pass=$((pass + 1)); printf '  ok   local main was not advanced (still checked out elsewhere)\n'
  else
    fail=$((fail + 1)); printf '  FAIL local main was not advanced (still checked out elsewhere)\n'
  fi
  teardown
}

test_worktree_resolves_parent_beside_primary_checkout() {
  echo "test: running from a linked worktree of THIS repo resolves siblings beside the primary checkout, not beside the worktree"
  setup
  mk_primary_with_worktree
  mkdir -p "$WT_DIR/scripts"
  cp "$SCRIPT" "$WT_DIR/scripts/sync-repos.sh"
  chmod +x "$WT_DIR/scripts/sync-repos.sh"
  printf '%s\n' '{"repos":[{"name":"repo-a","slug":"testorg/repo-a","tier":"core"}]}' > "$WT_DIR/repos.json"
  mk_remote repo-a

  # WS_PARENT is exported by setup() for every other test; this is the one
  # test that must NOT have it, since it exists to prove what the script does
  # in its absence. `env -u` unsets it for this single invocation only.
  OUT="$(env -u WS_PARENT "$WT_DIR/scripts/sync-repos.sh" 2>&1)"
  RC=$?

  assert_rc "exits 0" 0
  assert_contains "reports the clone" "+ repo-a"
  local primary_parent wt_parent
  primary_parent="$(dirname "$PRIMARY")"
  wt_parent="$(dirname "$WT_DIR")"
  if [ -d "$primary_parent/repo-a" ]; then
    pass=$((pass + 1)); printf '  ok   cloned beside the primary checkout\n'
  else
    fail=$((fail + 1)); printf '  FAIL cloned beside the primary checkout\n'
  fi
  if [ -d "$wt_parent/repo-a" ]; then
    fail=$((fail + 1)); printf '  FAIL wrongly cloned beside the worktree instead\n'
  else
    pass=$((pass + 1)); printf '  ok   did not clone beside the worktree\n'
  fi
  teardown
}

test_preflight_gh_unauthenticated
test_preflight_missing_tool
test_help_flag
test_unknown_flag
test_print_shows_both_tiers
test_local_override_wins
test_legacy_url_manifest_entries
test_tier_selection
test_clone_and_idempotency
test_clone_failure_continues
test_empty_repo_does_not_abort_the_run
test_fast_forward_on_default_branch
test_dirty_on_default_branch_is_not_merged
test_untracked_only_does_not_block_fast_forward
test_incoming_file_colliding_with_untracked_is_classified
test_feature_branch_advances_default_branch
test_diverged_default_branch_both_shapes
test_no_local_default_branch_is_not_created
test_default_branch_checked_out_in_worktree_is_reported_distinctly
test_worktree_resolves_parent_beside_primary_checkout
report
