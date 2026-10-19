#!/usr/bin/env bash
# Check that this machine can run this workspace: the first thing to run after
# cloning it, and the thing to rerun when a session cannot read a member repo.
#
#   tools          git, jq, claude, and gh signed in (`gh auth login`).
#   member repos   every core repos.json row cloned beside this workspace.
#                  An adjacent one missing is reported, not failed.
#   settings       .claude/settings.json lists each member repo and its -wt/
#                  worktree directory, plus this workspace's own -wt/, and
#                  nothing repos.json does not claim.
#   trust          Claude Code has been opened here and its trust prompt
#                  accepted, here or on a directory above. Until then it ignores
#                  .claude/settings.json, so a session cannot read the member repos.
#
# A workspace with tools of its own (an MCP server, a runtime version, a private
# registry) adds its checks below the trust check, in the same ok/warn/fail shape.
#
# --settings-only runs the settings check alone: it needs no clones, no trust
# and no gh sign-in, so it is the one CI can run on every pull request.
#
# Read-only; needs jq. Usage: check-setup.sh [--settings-only]
# Exit 0 ready, 1 something to fix, 2 could not check.
set -uo pipefail
unset CDPATH   # an exported CDPATH makes `cd` echo its path and corrupts $( ) captures

ws="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

only=""
case "${1:-}" in
  -h|--help) awk 'NR>1 && !/^#/{exit} NR>1' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --settings-only) only=settings ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

command -v jq >/dev/null 2>&1 || { echo "FAIL  jq is not installed; this check and sync-repos.sh need it" >&2; exit 2; }
[ -f "$ws/repos.json" ] || { echo "no repos.json in $ws" >&2; exit 2; }
jq -e '.repos | type == "array"' "$ws/repos.json" >/dev/null 2>&1 || { echo "repos.json in $ws has no repos array" >&2; exit 2; }

# The primary checkout, even from a worktree: repos sit beside it, and trust is kept for it.
primary="$ws"
common="$(git -C "$ws" rev-parse --git-common-dir 2>/dev/null)" && primary="$(dirname "$(cd "$ws" && cd "$common" && pwd -P)")"
parent="$(dirname "$primary")"
self="$(basename "$primary")"

failures=0
fail() { failures=$((failures + 1)); printf 'FAIL  %s\n' "$1"; }
warn() { printf 'warn  %s\n' "$1"; }
ok() { printf 'ok    %s\n' "$1"; }

if [ -z "$only" ]; then
command -v git >/dev/null 2>&1 && ok "git" || fail "git is not installed"
command -v claude >/dev/null 2>&1 && ok "claude" || fail "claude is not installed; see https://code.claude.com/docs/en/overview"
if ! command -v gh >/dev/null 2>&1; then
  fail "gh is not installed; see https://cli.github.com"
elif gh auth status >/dev/null 2>&1; then
  ok "gh signed in"
else
  fail "gh is not signed in; run: gh auth login"
fi

missing=""
while IFS=$'\t' read -r name tier; do
  [ "$name" = "$self" ] && continue
  [ -d "$parent/$name" ] && continue
  if [ "$tier" = core ]; then fail "$name is not cloned beside the workspace"; missing=1
  else warn "$name (adjacent) is not cloned; sync-repos.sh --all fetches it if you need it"; fi
done < <(jq -r '.repos[] | [.name, (.tier // "core")] | @tsv' "$ws/repos.json")
if [ -n "$missing" ]; then
  printf '      clone them with: %s/scripts/sync-repos.sh\n' "$ws"
else
  ok "core member repos in $parent"
fi
fi

settings="$ws/.claude/settings.json"
if [ ! -f "$settings" ]; then
  fail ".claude/settings.json is missing, so no session can read the member repos"
elif ! jq -e . "$settings" >/dev/null 2>&1; then
  fail ".claude/settings.json is not valid JSON"
else
  want="$( { echo "../$self-wt"; jq -r --arg s "$self" '.repos[].name | select(. != $s) | "../\(.)", "../\(.)-wt"' "$ws/repos.json"; } | sort -u)"
  have="$(jq -r '.permissions.additionalDirectories // [] | .[]' "$settings" | sort -u)"
  drift=""
  for d in $(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$have")); do
    fail "$d is expected from repos.json and missing from .claude/settings.json additionalDirectories"; drift=1
  done
  for d in $(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$have")); do
    fail "$d is in .claude/settings.json additionalDirectories and not in repos.json"; drift=1
  done
  [ -z "$drift" ] && ok ".claude/settings.json matches repos.json"
fi

if [ -z "$only" ]; then
trusted=false; d="$primary"
while [ "$trusted" != true ] && [ "$d" != / ]; do
  trusted="$(jq -r --arg p "$d" '.projects[$p].hasTrustDialogAccepted // false' "$HOME/.claude.json" 2>/dev/null || echo false)"
  d="$(dirname "$d")"
done
if [ "$trusted" = true ]; then
  ok "workspace trusted by Claude Code"
else
  fail "Claude Code has not been trusted in $primary; run \`claude\` there once and accept the trust prompt, or it ignores .claude/settings.json and cannot read the member repos"
fi
fi

if [ "$failures" -gt 0 ]; then
  printf '\n%s thing(s) to fix.\n' "$failures"
  exit 1
fi
[ -n "$only" ] && { printf '\nsettings: in sync with repos.json.\n'; exit 0; }
printf '\nsetup: ready. Start every session with `claude` in %s.\n' "$primary"
exit 0
