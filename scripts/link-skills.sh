#!/usr/bin/env bash
set -euo pipefail

# This is the installer. It links all skills in the repository into the local
# skill directory each agent harness actually reads:
#   - ~/.claude/skills:          Claude Code
#   - $CODEX_HOME/skills:        Codex (defaults to ~/.codex/skills)
#   - ~/.agents/skills:          other Agent Skills-compatible harnesses
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date, and an edit is live in the next session.
#
# Codex reads $CODEX_HOME/skills, NOT ~/.agents/skills: its bundled
# skill-installer installs to "$CODEX_HOME/skills/<skill-name> (defaults to
# ~/.codex/skills)". Linking only into ~/.agents/skills leaves Codex seeing
# none of these. Codex's own bundled skills live in a `.system` subdirectory
# there and are never touched: cleanup skips `.system` explicitly, and no skill
# in this repo is named `.system`.

REPO="$(cd "$(dirname "$0")/.." && pwd -P)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DESTS=("$HOME/.claude/skills" "$CODEX_HOME/skills" "$HOME/.agents/skills")

# Resolve as much of a path as exists, then restore any missing suffix. Unlike
# `readlink -f` alone, this keeps the full destination of a dangling link.
canonicalize_allow_missing() {
  local path="$1"
  local parent
  local part
  local symlink_target
  local suffix=""
  local symlink_count=0

  while [ ! -e "$path" ]; do
    if [ -L "$path" ]; then
      symlink_target="$(readlink "$path")"
      case "$symlink_target" in
        /*) path="$symlink_target" ;;
        *) path="$(dirname "$path")/$symlink_target" ;;
      esac
      symlink_count=$((symlink_count + 1))
      [ "$symlink_count" -le 40 ] || return 1
    else
      part="$(basename "$path")"
      suffix="/$part$suffix"
      parent="$(dirname "$path")"
      [ "$parent" != "$path" ] || return 1
      path="$parent"
    fi
  done

  path="$(readlink -f "$path")" || return 1
  printf '%s%s\n' "$path" "$suffix"
}

resolved_link_target() {
  local link="$1"
  local link_target
  local target_path

  link_target="$(readlink "$link")"
  case "$link_target" in
    /*) target_path="$link_target" ;;
    *) target_path="$(dirname "$link")/$link_target" ;;
  esac

  canonicalize_allow_missing "$target_path"
}

# Collect the repo's skills once, link into every destination. `deprecated/`
# is retired, and `misc/` is kept around but rarely used and not promoted (see
# each bucket's own README): neither belongs in a daily-driver skill
# directory, so both are skipped here, same as everywhere else non-promoted
# skills are kept out. `in-progress/` IS still linked: it's public on purpose,
# feedback wanted, and this local install is exactly where that feedback loop
# runs.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/misc/*' -print0)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  while IFS= read -r -d '' target; do
    if [ "$(basename "$target")" = ".system" ]; then
      continue
    fi

    link_target="$(readlink "$target")"
    if ! absolute_target="$(resolved_link_target "$target")"; then
      continue
    fi

    remove=false
    case "$absolute_target" in
      "$REPO/skills/misc/"*|"$REPO/skills/deprecated/"*)
        remove=true
        ;;
      "$REPO/skills/"*)
        if [ ! -e "$target" ]; then
          remove=true
        fi
        ;;
    esac

    if [ "$remove" = true ]; then
      rm "$target"
      echo "removed $(basename "$target") -> $link_target ($DEST)"
    fi
  done < <(find "$DEST" -mindepth 1 -maxdepth 1 -type l -print0)

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    if [ -L "$target" ]; then
      if ! absolute_target="$(resolved_link_target "$target")"; then
        echo "warning: $target could not be resolved safely. Leaving it untouched." >&2
        continue
      fi
      if [ "$absolute_target" = "$src" ]; then
        continue
      fi

      case "$absolute_target" in
        "$REPO/skills/"*) ;;
        *)
          echo "warning: $target is a link from outside this repo. Leaving it untouched." >&2
          continue
          ;;
      esac
    fi

    # A real path here is someone's own skill of the same name, not a link this
    # script owns. Never delete it.
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "warning: $target is a real path, not a link from this repo. Leaving it untouched." >&2
      continue
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($DEST)"
  done
done
