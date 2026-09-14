#!/usr/bin/env bash
# Print the path of the workspace that claims a repo, or nothing.
#
# Usage: find-workspace.sh [<repo-dir>]     (default: the current directory)
# Exit:  0 and the absolute path on stdout when a workspace claims the repo
#        1 and no output otherwise
#
# A workspace claims a repo when it holds a repos.json whose repos[].slug
# includes that repo's origin slug. Keying on the manifest rather than on
# directory adjacency is the whole point: an unrelated repo sitting beside the
# clones is not a member, and "is a sibling of" would wrongly claim it.
#
# Silence plus exit 1 is the "no workspace" answer, so a caller can branch on it
# and fall back to single-repo behaviour. It is never an error.
set -uo pipefail

# A user CDPATH makes `cd <bare-name>` print the resolved directory to stdout as
# well as changing dir, which would corrupt the path this script emits.
unset CDPATH

repo="${1:-.}"
[ -d "$repo" ] || exit 1

command -v git >/dev/null 2>&1 || exit 1
command -v jq  >/dev/null 2>&1 || exit 1

# Normalise a remote URL to <owner>/<repo>. Handles the ssh form
# (git@host:owner/repo.git), the https form, and a missing .git suffix.
slug_of() {
  printf '%s\n' "$1" \
    | sed -e 's|^[a-z+]*://||' -e 's|^[^@]*@||' -e 's|^[^/:]*[:/]||' -e 's|\.git$||'
}

url="$(git -C "$repo" remote get-url origin 2>/dev/null)" || exit 1
[ -n "$url" ] || exit 1
slug="$(slug_of "$url")"
# Guard against a URL that normalises to something that is not owner/repo.
case "$slug" in
  */*) ;;
  *) exit 1 ;;
esac

# Search the repo's siblings. Resolve the repo's real parent through git, so a
# linked worktree looks beside the primary checkout rather than beside itself.
common="$(git -C "$repo" rev-parse --git-common-dir 2>/dev/null)" || exit 1
common="$(cd "$repo" && cd "$common" && pwd -P)" || exit 1
parent="$(dirname "$(dirname "$common")")"

for manifest in "$parent"/*/repos.json; do
  [ -f "$manifest" ] || continue
  if jq -e --arg s "$slug" 'any(.repos[]?; .slug == $s)' "$manifest" >/dev/null 2>&1; then
    (cd "$(dirname "$manifest")" && pwd -P)
    exit 0
  fi
done

exit 1
