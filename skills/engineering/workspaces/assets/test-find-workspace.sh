#!/usr/bin/env bash
# Hermetic tests for find-workspace.sh. No network, no real clones, no gh.
set -uo pipefail
unset CDPATH

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/find-workspace.sh"
pass=0; fail=0

ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n     wanted: %s\n     got:    %s\n' "$1" "$2" "$3"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi }

# A repo with an origin URL, no commits needed.
mk_repo() { mkdir -p "$1"; git -C "$1" init -q; git -C "$1" remote add origin "$2"; }
# A workspace directory holding a manifest that claims the given slugs.
mk_ws() {
  local dir="$1"; shift
  mkdir -p "$dir"
  { printf '{ "repos": ['
    local first=1 s
    for s in "$@"; do
      [ $first -eq 1 ] || printf ','
      printf '{ "slug": "%s", "tier": "core" }' "$s"; first=0
    done
    printf '] }\n'
  } > "$dir/repos.json"
}

# Resolve physically: on macOS mktemp -d returns /var/... which is a symlink to
# /private/var/..., and the script under test prints physical paths via pwd -P.
root="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$root"' EXIT

echo "test: a repo whose sibling workspace claims it"
mk_repo "$root/a/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/a/acme-workspace" "acme/svc" "acme/other"
check "finds the workspace" "$root/a/acme-workspace" "$(cd "$root/a/svc" && bash "$SUT")"
check "exits 0" "0" "$(cd "$root/a/svc" && bash "$SUT" >/dev/null; echo $?)"

echo "test: the https remote form resolves to the same slug"
mk_repo "$root/b/svc" "https://github.com/acme/svc.git"
mk_ws   "$root/b/acme-workspace" "acme/svc"
check "https form found" "$root/b/acme-workspace" "$(cd "$root/b/svc" && bash "$SUT")"

echo "test: a remote with no .git suffix still resolves"
mk_repo "$root/c/svc" "https://github.com/acme/svc"
mk_ws   "$root/c/acme-workspace" "acme/svc"
check "bare form found" "$root/c/acme-workspace" "$(cd "$root/c/svc" && bash "$SUT")"

echo "test: an adjacent workspace that does NOT claim the repo is not a match"
mk_repo "$root/d/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/d/other-workspace" "acme/unrelated"
check "no match" "" "$(cd "$root/d/svc" && bash "$SUT")"
check "exits 1" "1" "$(cd "$root/d/svc" && bash "$SUT" >/dev/null; echo $?)"

echo "test: with two workspaces present, the claiming one wins"
mk_repo "$root/e/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/e/aaa-workspace" "acme/unrelated"
mk_ws   "$root/e/zzz-workspace" "acme/svc"
check "picks the claimant, not the first" "$root/e/zzz-workspace" "$(cd "$root/e/svc" && bash "$SUT")"

echo "test: no origin remote"
mkdir -p "$root/f/svc"; git -C "$root/f/svc" init -q
mk_ws "$root/f/acme-workspace" "acme/svc"
check "no remote means no workspace" "" "$(cd "$root/f/svc" && bash "$SUT")"

echo "test: not a git repo at all"
mkdir -p "$root/g/plain"
mk_ws "$root/g/acme-workspace" "acme/svc"
check "non-repo means no workspace" "" "$(cd "$root/g/plain" && bash "$SUT")"

echo "test: a malformed manifest is skipped, not fatal"
mk_repo "$root/h/svc" "git@github.com:acme/svc.git"
mkdir -p "$root/h/broken-workspace"; printf 'not json at all\n' > "$root/h/broken-workspace/repos.json"
mk_ws "$root/h/good-workspace" "acme/svc"
check "skips the broken one and finds the good one" "$root/h/good-workspace" "$(cd "$root/h/svc" && bash "$SUT")"

echo "test: a manifest with no repos key does not crash"
mk_repo "$root/i/svc" "git@github.com:acme/svc.git"
mkdir -p "$root/i/empty-workspace"; printf '{}\n' > "$root/i/empty-workspace/repos.json"
check "no repos key means no match" "" "$(cd "$root/i/svc" && bash "$SUT")"

echo "test: a linked worktree resolves beside the PRIMARY checkout"
mk_repo "$root/j/svc" "git@github.com:acme/svc.git"
git -C "$root/j/svc" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
mk_ws "$root/j/acme-workspace" "acme/svc"
git -C "$root/j/svc" worktree add -q "$root/j/svc-wt/feature" -b feature 2>/dev/null
check "worktree finds the same workspace" "$root/j/acme-workspace" "$(cd "$root/j/svc-wt/feature" && bash "$SUT")"

echo "test: an explicit directory argument works without cd"
mk_repo "$root/k/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/k/acme-workspace" "acme/svc"
check "argument form" "$root/k/acme-workspace" "$(bash "$SUT" "$root/k/svc")"

echo "test: the caller's working directory is untouched"
before="$(pwd -P)"
bash "$SUT" "$root/k/svc" >/dev/null
check "cwd unchanged" "$before" "$(pwd -P)"

echo "test: a user CDPATH does not corrupt the output"
check "CDPATH-proof" "$root/k/acme-workspace" "$(CDPATH=/tmp bash "$SUT" "$root/k/svc")"

echo "test: standing inside a workspace resolves to it, with no git and no manifest entry"
mk_ws "$root/l/light-workspace" "acme/other"
mkdir -p "$root/l/light-workspace/notes"
check "workspace root" "$root/l/light-workspace" "$(cd "$root/l/light-workspace" && bash "$SUT")"
check "a subdir of it walks up" "$root/l/light-workspace" "$(cd "$root/l/light-workspace/notes" && bash "$SUT")"
check "exits 0" "0" "$(cd "$root/l/light-workspace" && bash "$SUT" >/dev/null; echo $?)"

echo "test: step 1 beats step 2, so being in a workspace is never ambiguous"
mk_repo "$root/m/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/m/one-workspace" "acme/svc"
mk_ws   "$root/m/two-workspace" "acme/svc"
check "inside one of them, that one wins" "$root/m/one-workspace" "$(cd "$root/m/one-workspace" && bash "$SUT")"

echo "test: a repo claimed by two workspaces is ambiguous, not silently first"
lines="$(cd "$root/m/svc" && bash "$SUT" | sort | tr '\n' ' ')"
check "both reported" "$root/m/one-workspace $root/m/two-workspace " "$lines"
check "exits 2" "2" "$(cd "$root/m/svc" && bash "$SUT" >/dev/null; echo $?)"

echo "test: a repo claimed by exactly one is still a clean single answer"
mk_repo "$root/n/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/n/only-workspace" "acme/svc"
check "single claimant" "$root/n/only-workspace" "$(cd "$root/n/svc" && bash "$SUT")"
check "exits 0" "0" "$(cd "$root/n/svc" && bash "$SUT" >/dev/null; echo $?)"

echo "test: three claimants all reported"
mk_repo "$root/o/svc" "git@github.com:acme/svc.git"
mk_ws   "$root/o/a-workspace" "acme/svc"
mk_ws   "$root/o/b-workspace" "acme/svc"
mk_ws   "$root/o/c-workspace" "acme/svc"
check "count is three" "3" "$(cd "$root/o/svc" && bash "$SUT" | wc -l | tr -d ' ')"

echo
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
