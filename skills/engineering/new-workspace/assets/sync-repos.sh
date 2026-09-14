#!/usr/bin/env bash
# Clone and refresh this workspace's member repos as SIBLINGS of the workspace dir.
# Clones what is missing, fast-forwards what is present, and never modifies
# uncommitted or diverged work.
#
# Usage: sync-repos.sh [--print] [--all] [<name>...]
#   (no args)   sync the core tier
#   --all       sync core + adjacent tiers
#   <name>...   sync named repos from any tier
#   --print     show the resolved manifest and exit (no writes, no gh auth)
#
# Env: WS_PARENT   parent directory clones land in (default: this workspace's parent)
#
# Two properties of this file are deliberate and easy to "fix" by mistake:
# every string is project-neutral (it is a template, copied into workspaces it
# knows nothing about), and there are no em-dashes anywhere, which this repo's
# prose rule forbids. Both survive any behavior change made here.
set -euo pipefail

# A user CDPATH makes `cd <bare-relative-name>` print the resolved directory
# to stdout in addition to changing dir, silently corrupting every
# `x="$(cd ... && pwd)"` capture below (verified empirically: with CDPATH set,
# `common="$(cd "$ws" && cd "$common" && pwd -P)"` in resolve_parent came back
# as two duplicated lines instead of one). Disable it for this script only.
unset CDPATH

ws="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Clones are siblings of the PRIMARY checkout. When this script runs from a
# linked worktree, $ws is the worktree, and its parent is the -wt/ directory, not
# the repo root's parent, so resolve through git's common dir instead.
resolve_parent() {
  local common
  common="$(git -C "$ws" rev-parse --git-common-dir 2>/dev/null)" || common=""
  if [ -n "$common" ]; then
    common="$(cd "$ws" && cd "$common" && pwd -P)"   # handles relative ".git"
    dirname "$(dirname "$common")"
  else
    dirname "$ws"                                     # not a git repo: fall back
  fi
}
parent="${WS_PARENT:-$(resolve_parent)}"

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^#\{1,\} \{0,1\}//'; }

# ---- args (bash 3.2: space-delimited string, never an array) ----
print_only=0
want_all=0
names=""
for arg in "$@"; do
  case "$arg" in
    --print) print_only=1 ;;
    --all) want_all=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: $arg" >&2; usage >&2; exit 2 ;;
    *) names="$names $arg" ;;
  esac
done
names="${names# }"

# ---- preflight ----
require_tools() {
  local missing="" c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
  done
  if [ -n "$missing" ]; then
    echo "missing required tool(s):$missing" >&2
    echo "  fix: brew install$missing" >&2
    exit 1
  fi
}

require_gh_auth() {
  if ! gh auth status >/dev/null 2>&1; then
    echo "gh is not authenticated (required to clone and fetch)." >&2
    echo "  fix: gh auth login" >&2
    exit 1
  fi
}

# ---- manifest ----
# Emits name<TAB>slug<TAB>tier<TAB>branch. Accepts either `slug` or a legacy
# `url` (the old README told people to write `url` in repos.local.json).
# repos.local.json is merged last, so it overrides by name.
read_manifest() {
  local local_json='{"repos":[]}'
  [ -f "$ws/repos.local.json" ] && local_json="$(cat "$ws/repos.local.json")"
  jq -rn --argjson local "$local_json" '
    (input.repos + ($local.repos // []))
    | map(
        if (.slug // .url) == null then
          error("manifest entry needs slug or url: \(.)")
        else . end
        | ((.slug // (.url
            | sub("^git@github\\.com:"; "")
            | sub("^https://github\\.com/"; "")
            | sub("\\.git$"; ""))) ) as $slug
        | { name: (.name // ($slug | split("/") | last)),
            slug: $slug,
            tier: (.tier // "core"),
            branch: (.defaultBranch // "") }
      )
    | group_by(.name) | map(.[-1])
    | .[] | [ .name, .slug, .tier, .branch ] | @tsv
  ' "$ws/repos.json"
}

verify_names() {
  local manifest="$1" n known
  known="$(printf '%s\n' "$manifest" | cut -f1)"
  for n in $names; do
    if ! printf '%s\n' "$known" | grep -qx "$n"; then
      echo "unknown repo: $n" >&2
      echo "  known: $(printf '%s\n' "$known" | tr '\n' ' ')" >&2
      exit 2
    fi
  done
}

# Filter the manifest on stdin by explicit names, else by tier.
select_repos() {
  local name slug tier branch
  while IFS=$'\t' read -r name slug tier branch; do
    [ -n "$name" ] || continue
    if [ -n "$names" ]; then
      case " $names " in
        *" $name "*) ;;
        *) continue ;;
      esac
    elif [ "$want_all" -eq 0 ] && [ "$tier" != "core" ]; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$slug" "$tier" "$branch"
  done
}

# Resolve a clone's default branch: origin/HEAD, else re-derive it, else the
# manifest's defaultBranch, else main. A fresh `git clone` does set origin/HEAD,
# so the fallbacks are defensive only.
default_branch() {
  local dir="$1" mbranch="${2:-}" b
  b="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$b" ]; then
    git -C "$dir" remote set-head origin -a >/dev/null 2>&1 || true
    b="$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  fi
  b="${b#origin/}"
  [ -n "$b" ] || b="$mbranch"
  [ -n "$b" ] || b="main"
  printf '%s\n' "$b"
}

# Flattens possibly multi-line git stderr into one line: emit()'s printf is a
# single row per repo, and an embedded newline would break the report.
oneline() { printf '%s' "$1" | tr '\n' ' '; }

# ---- per-repo sync ----
sync_one() {
  local name="$1" slug="$2" mbranch="$3" dest
  dest="$parent/$name"

  if [ ! -d "$dest/.git" ]; then
    if gh repo clone "$slug" "$dest" >/dev/null 2>&1; then
      cloned "$name" "cloned → $dest"
    else
      fail "$name" "clone failed: $slug (no access, or wrong slug)"
    fi
    return
  fi

  refresh_one "$name" "$dest" "$mbranch"
}

# Refreshes an already-cloned repo: fast-forwards a clean checkout of the
# default branch (case 2), reports dirty or diverged states without touching
# them (case 3), and fast-forwards the default branch in place while a
# different branch stays checked out (case 4). Pulled out of sync_one as a
# pure move (no behavior change) once the clone-vs-refresh halves stopped
# fitting comfortably in one function.
refresh_one() {
  local name="$1" dest="$2" mbranch="$3"
  local db cur dirty before after count ferr merr
  db="$(default_branch "$dest" "$mbranch")"
  cur="$(git -C "$dest" branch --show-current 2>/dev/null || true)"
  # --untracked-files=no on purpose: an untracked file is not uncommitted
  # *work*, and on its own it cannot block a fast-forward. The one case where
  # it interacts with the merge at all, an incoming commit adding a path that
  # exists locally as untracked, git refuses by itself, and case 2 classifies
  # that refusal rather than clobbering anything. Counting untracked files
  # here instead left repos stale for editor dirs, local CLAUDE.md notes and
  # stray docs that no merge would ever have touched.
  dirty=0
  if [ -n "$(git -C "$dest" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    dirty=1
  fi

  if ! ferr="$(git -C "$dest" fetch --quiet origin 2>&1 >/dev/null)"; then
    fail "$name" "fetch failed: $(oneline "$ferr")"
    return
  fi

  if [ "$cur" = "$db" ]; then
    # Case 2/3: the default branch is checked out.
    if [ "$dirty" -eq 1 ]; then
      warn "$name" "uncommitted changes; fetched only, not merged"
      return
    fi
    before="$(git -C "$dest" rev-parse --short HEAD 2>/dev/null || true)"
    if [ -z "$before" ]; then
      # Unborn HEAD: a clone with no commits yet. `rev-parse HEAD` has
      # nothing to resolve (exit 128), which under `set -e` would otherwise
      # abort the whole run rather than just this repo.
      warn "$name" "no commits yet (empty repo), nothing to compare"
      return
    fi
    # stderr is captured rather than discarded: now that untracked files are
    # no longer gated out above, a refused fast-forward is not necessarily
    # divergence, and the message is the only thing that tells them apart.
    if merr="$(git -C "$dest" merge --ff-only "origin/$db" 2>&1 >/dev/null)"; then
      after="$(git -C "$dest" rev-parse --short HEAD)"
      if [ "$before" = "$after" ]; then
        ok "$name" "up to date ($db)"
      else
        count="$(git -C "$dest" rev-list --count "$before..$after")"
        updated "$name" "$db  $before..$after ($count commits)"
      fi
    else
      case "$merr" in
        # Must precede the generic overwrite arm: git's untracked message also
        # contains "would be overwritten by merge".
        *"untracked working tree files would be overwritten"*)
          warn "$name" "$db adds a file you have untracked; fetched only, not merged" ;;
        *"would be overwritten by merge"*)
          warn "$name" "$db would overwrite local changes; fetched only, not merged" ;;
        *"ot possible to fast-forward"*|*"Need to specify how"*|*"refusing to merge unrelated"*)
          warn "$name" "$db diverged from origin/$db; fetched only, not merged" ;;
        *)
          warn "$name" "$db not advanced: $(oneline "${merr:-unknown merge error}")" ;;
      esac
    fi
  else
    # Case 4: the default branch is NOT checked out, so the refspec is legal
    # and git enforces fast-forward-only for us.
    [ -n "$cur" ] || cur="detached HEAD"
    # Never let the refspec create $db from nothing (git happily does: a
    # fast-forward from no ref at all, which would violate "no branch
    # create"). Only proceed if $db already exists locally.
    if ! git -C "$dest" rev-parse --verify --quiet "refs/heads/$db" >/dev/null; then
      warn "$name" "on $cur, fetched; no local $db"
      return
    fi
    before="$(git -C "$dest" rev-parse --short "$db" 2>/dev/null || true)"
    # Not --quiet, and stderr is captured (not discarded): the refspec fetch
    # can fail for more than one reason, and we need the message to tell them
    # apart rather than mislabeling everything "diverged". --quiet would
    # additionally suppress the "non-fast-forward" rejection text entirely
    # (verified empirically), which we need to classify real divergence.
    if ferr="$(git -C "$dest" fetch origin "$db:$db" 2>&1 >/dev/null)"; then
      after="$(git -C "$dest" rev-parse --short "$db")"
      if [ "$before" = "$after" ]; then
        warn "$name" "on $cur, fetched; $db already up to date"
      else
        warn "$name" "on $cur, fetched; $db fast-forwarded $before..$after"
      fi
    else
      case "$ferr" in
        *"checked out at"*)
          # git refuses this refspec whenever $db is checked out ANYWHERE in
          # this repo, including a linked worktree, not just $dest itself.
          # Distinct from divergence: nothing here failed to fast-forward.
          warn "$name" "on $cur, fetched; $db is checked out in another worktree, not advanced" ;;
        *"non-fast-forward"*)
          warn "$name" "on $cur, fetched; $db diverged, not advanced" ;;
        *)
          warn "$name" "on $cur, fetched; $db not advanced: $(oneline "${ferr:-unknown fetch error}")" ;;
      esac
    fi
  fi
}

# ---- reporting ----
n_ok=0
n_updated=0
n_cloned=0
n_warn=0
n_fail=0

emit() { printf '%s %-22s %s\n' "$1" "$2" "$3"; }
ok()      { n_ok=$((n_ok + 1));           emit "✓" "$1" "$2"; }
updated() { n_updated=$((n_updated + 1)); emit "↓" "$1" "$2"; }
cloned()  { n_cloned=$((n_cloned + 1));   emit "+" "$1" "$2"; }
warn()    { n_warn=$((n_warn + 1));       emit "!" "$1" "$2"; }
fail()    { n_fail=$((n_fail + 1));       emit "✗" "$1" "$2"; }

summary() {
  printf '\n%d cloned, %d updated, %d up to date, %d need attention, %d failed\n' \
    "$n_cloned" "$n_updated" "$n_ok" "$n_warn" "$n_fail"
  [ "$n_fail" -eq 0 ] || exit 1
}

# ---- main ----
require_tools git jq column

manifest="$(read_manifest)"
[ -n "$names" ] && verify_names "$manifest"
selected="$(printf '%s\n' "$manifest" | select_repos)"
if [ -z "$selected" ]; then
  echo "no repos selected" >&2
  exit 2
fi

if [ "$print_only" -eq 1 ]; then
  { printf 'NAME\tSLUG\tTIER\tBRANCH\n'; printf '%s\n' "$selected"; } | column -t -s "$(printf '\t')"
  exit 0
fi

require_tools gh
require_gh_auth

mkdir -p "$parent"

while IFS=$'\t' read -r name slug tier branch; do
  [ -n "$name" ] || continue
  sync_one "$name" "$slug" "$branch"
done <<< "$selected"

summary
