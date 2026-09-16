#!/usr/bin/env bash
# Resolve the workspace in effect, or report that there is none, or that it is
# ambiguous.
#
# Usage: find-workspace.sh [<dir>]          (default: the current directory)
# Exit:  0  one workspace, its absolute path on stdout
#        1  none, no output: treat as a single-repo run, this is not an error
#        2  ambiguous, every claimant on stdout one per line: ask which
#
# Resolution runs in two steps, in this order.
#
#   1. Are we already inside a workspace? Walk up from <dir> looking for a
#      directory that holds a repos.json. Standing in a workspace is
#      unambiguous, needs no git and no remote, and is how a workspace session
#      normally starts, so it answers first and answers alone.
#
#   2. Which workspaces claim this repo? Scan the repo's siblings for a
#      repos.json whose repos[].slug includes this repo's origin slug. Keying on
#      the manifest rather than on adjacency is the point: an unrelated repo
#      beside the clones is not a member, and several workspaces can sit beside
#      many repos.
#
# Membership is many-to-many. One repo genuinely belonging to several workspaces
# is normal, not a misconfiguration, so step 2 reports every claimant rather than
# picking one. Picking silently is how a term meant for one workspace's glossary
# gets written into another's.
set -uo pipefail

# A user CDPATH makes `cd <bare-name>` print the resolved directory to stdout as
# well as changing dir, which would corrupt the paths this script emits.
unset CDPATH

start="${1:-.}"
[ -d "$start" ] || exit 1

command -v jq >/dev/null 2>&1 || exit 1

abs() { (cd "$1" && pwd -P); }

# ---- step 1: already inside a workspace ----
dir="$(abs "$start")" || exit 1
while :; do
  if [ -f "$dir/repos.json" ]; then
    printf '%s\n' "$dir"
    exit 0
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

# ---- step 2: claimed by a sibling workspace ----
command -v git >/dev/null 2>&1 || exit 1

# Normalise a remote URL to <owner>/<repo>: ssh form, https form, bare form.
slug_of() {
  printf '%s\n' "$1" \
    | sed -e 's|^[a-z+]*://||' -e 's|^[^@]*@||' -e 's|^[^/:]*[:/]||' -e 's|\.git$||'
}

url="$(git -C "$start" remote get-url origin 2>/dev/null)" || exit 1
[ -n "$url" ] || exit 1
slug="$(slug_of "$url")"
case "$slug" in */*) ;; *) exit 1 ;; esac

# Resolve the repo's real parent through git, so a linked worktree looks beside
# the primary checkout rather than beside itself.
common="$(git -C "$start" rev-parse --git-common-dir 2>/dev/null)" || exit 1
common="$(cd "$start" && cd "$common" && pwd -P)" || exit 1
parent="$(dirname "$(dirname "$common")")"

found=""
count=0
for manifest in "$parent"/*/repos.json; do
  [ -f "$manifest" ] || continue
  if jq -e --arg s "$slug" 'any(.repos[]?; .slug == $s)' "$manifest" >/dev/null 2>&1; then
    found="$found$(abs "$(dirname "$manifest")")
"
    count=$((count + 1))
  fi
done

case "$count" in
  0) exit 1 ;;
  1) printf '%s' "$found"; exit 0 ;;
  *) printf '%s' "$found"; exit 2 ;;
esac
