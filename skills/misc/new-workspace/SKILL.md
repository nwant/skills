---
name: new-workspace
description: "Scaffold a multi-repo workspace for a set of sibling repos: a CLAUDE.md synthesis plus repo index, a repos.json manifest, a .claude/settings.json that opens the member repos and their worktrees, a sync script, and the matching shell launcher. Also upgrades an existing ad-hoc workspace to the full pattern."
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, AskUserQuestion
---

# Create a new multi-repo Claude workspace

A **workspace** is a thin coordination directory at `<root>/<name>-workspace`,
where `<root>` is where the operator keeps clones (commonly `~/github`, but
confirm, see Phase 0). It holds the cross-repo synthesis that lives in no
single repo, plus an index of the member repos. Member repos are **siblings**
(`<root>/<repo>`), each with its own git history and its own `CLAUDE.md`. The
workspace never vendors them.

This skill is self-contained: everything it needs to build the full tier is in
`assets/` next to this file. Resolve that directory once at the start:

```bash
ASSETS="<this skill's base directory>/assets"   # absolute, from the banner
[ -f "$ASSETS/sync-repos.sh" ] && echo "$ASSETS" || echo MISSING
```

The base directory is the one the harness prints when this skill loads, so the
path holds wherever the skill is installed. If it prints `MISSING`, say so rather than improvising a substitute for
`sync-repos.sh`. The `assets/` copies are the only portable source: a workspace
you have seen elsewhere is not one the operator can necessarily read.

## Finding the workspace from inside a member repo

This layout is what lets any skill discover it is in a workspace, which matters
because a skill running inside a member repo otherwise cannot see the cross-repo
material above it: shared standards, a tracker config, a glossary that spans repos.

**The mechanism lives in the `workspaces` skill**, as a tested script rather than a
snippet to retype. Call the Skill tool with "workspaces" for the probe, the
vocabulary, and the rules for which copy of `CONTEXT.md`, `docs/adr/` or
`docs/agents/` a given artifact belongs to.

What this skill owes that mechanism is the **layout it depends on**: member repos as
siblings, and a `repos.json` in the workspace whose `repos[].slug` lists them. The
probe keys on the manifest claiming the repo rather than on directory adjacency,
because an unrelated repo sitting beside the clones is not a member, and with several
workspaces as siblings of many repos adjacency cannot disambiguate. That is why the
manifest is in both tiers.

## Non-negotiable rules

1. **Never eager-`@`-import a member repo's `CLAUDE.md`** into the workspace
   file. Eager imports pull every repo's full context into every session. The
   workspace file *points at* them ("read the repo's CLAUDE.md on demand").
2. **Each repo owns its own `CLAUDE.md`.** Repo-intrinsic facts do not get
   copied into the workspace file: only what spans repos (cross-surface maps,
   data provenance, shared contracts, cross-service local-dev chains).
3. **Member repos are gitignored** in the workspace repo. They are siblings that
   happen to sit next to it; a stray `git add` of one would nest a repo.
   **Everything else the workspace owns is committed**: `.claude/skills/`,
   `.claude/agents/`, `.claude/settings.json`, `docs/`. A teammate who clones it
   gets exactly what you run. Personal ignores go in `.git/info/exclude`, which is
   per-clone; a personal path in `.gitignore` silently swallows a teammate's file
   of the same name.
4. **Code changes happen in a worktree, never the primary checkout.** Each repo,
   the workspace included, gets a sibling `<root>/<repo>-wt/<slug>/` per task, and
   every primary checkout stays on its default branch. Instruction files are read
   at session start, so a workspace checkout left on a branch hands every new
   session that branch's unreviewed `CLAUDE.md`.
5. **Never state a cross-cutting fact you did not verify** against the actual
   code, git history, or config. An unverified claim is labeled a hypothesis or
   left out. A `CLAUDE.md` full of plausible-sounding fiction is worse than an
   empty one.
6. **Don't lead shell commands with `cd`.** Pass paths (`git -C <path>`,
   `rg <pat> /abs/path`). The exception is the interactive shell aliases, where
   `cd` into the workspace is the entire point.
7. **The shell rc file is edited surgically.** Back it up, append a new section,
   never reflow or "tidy" the existing blocks, and syntax-check before sourcing.

## Phase 0: Gather inputs and check the machine

**Portability preflight.** Don't assume this machine matches the one the skill
was written on. Establish, don't guess:

```bash
echo "shell: $SHELL"; uname -s
ls -d ~/github ~/src ~/dev ~/code ~/repos ~/Projects 2>/dev/null   # where clones live
for c in git gh jq column rg fd fzf bat eza; do
  command -v "$c" >/dev/null || echo "missing: $c"
done
gh auth status 2>&1          # never truncate; multi-host setups list each host
claude --help 2>/dev/null | grep -oE '\-\-(effort|add-dir|model)' | sort -u
```

- **`<root>`**: the clone parent. Take the directory that already has the most
  clones in it; if ambiguous, ask. Every path below is relative to it.
- **Shell rc file**: `~/.zshrc` for zsh, `~/.bashrc` (Linux) or
  `~/.bash_profile` (mac bash) for bash. Everything in Phase 4 targets whichever
  one is real; the function syntax in the template is POSIX-compatible and works
  in both, but `zsh -n` becomes `bash -n`.
- **`gh` must be authenticated to the host the repos actually live on.** Read the
  host off a real remote (`git -C <root>/<repo> remote get-url origin`) and
  confirm `gh auth status` lists it. An unauthenticated enterprise host makes
  every clone fail as "no access, or wrong slug", which reads like a bad manifest
  and sends the operator debugging the wrong thing. If the host is missing, stop
  and tell them to run `gh auth login --hostname <host>`; do not proceed and let
  the whole sync fail repo by repo.
- **Missing tools**: `git`, `gh`, `jq`, `column` are *required* for the full
  tier's script; `rg`/`fd`/`fzf`/`bat`/`eza` are only needed by the optional
  search helpers. Report what's missing with the right installer for the
  platform (`brew install` on mac, `apt`/`dnf` on Linux) instead of emitting
  aliases that fail at call time.
- **CLI flags**: confirm `--effort` exists in the installed Claude Code before
  putting it in an alias, and note that `opus[1m]`
  (1M-context) is entitlement-gated. If `--effort` isn't supported, drop it
  rather than shipping a broken launcher; if `[1m]` isn't available, use plain
  `--model opus`.

Then ask the operator (one batched `AskUserQuestion` round) for anything not
already stated:

- **Workspace name** → directory is `<root>/<name>-workspace`, alias is
  `cc-<name>`, search helpers are `<name>-rg` / `<name>-find` / `<name>-cd`.
- **Member repos**, and for each: the GitHub `owner/repo` slug and whether it is
  **`core`** (owned by this team, cloned by default) or **`adjacent`**
  (referenced by the notes but owned by another team / read on demand).
- **Shared or personal?** A *shared* workspace becomes its own GitHub repo
  (README, `repos.json`, `scripts/`, committed skills). A *personal* one is a
  local directory with `CLAUDE.md` and `.claude/` only.
- **Shared only: protect `main`?** Default yes: a ruleset requiring a reviewed
  pull request, with no bypass. The workspace's `CLAUDE.md` steers every session
  in every member repo, so an unreviewed edit to it is a change to everyone's
  agent.
- **Which build tier** (below).

If the operator hands you repos without slugs, resolve them:
`gh repo list <org> --limit 200 --json name,nameWithOwner`, or read the remote
of an already-present clone (`git -C <root>/<repo> remote get-url origin`). Do
not guess a slug, because a wrong one produces a clone failure they debug later.

## Phase 1: Pick the build tier

Not every workspace earns the full scaffold:

| Tier | Contents | When |
|---|---|---|
| **Light** | `CLAUDE.md`, `repos.json`, and `.claude/` (`settings.json`, skills, agents). No git repo, no scripts. | Solo exploration; repos already cloned; nobody else will use it. |
| **Full** | Light, plus `README.md`, `scripts/sync-repos.sh` and `scripts/check-setup.sh` with their tests, `.gitignore`, its own git repo, and (once pushed) a protected `main` with a CI check. | Teammates will clone it; repo set is large or churning; you want one-command clone/refresh. |

**`repos.json` is in both tiers on purpose.** It is data, not machinery, and it is
the only thing that makes a workspace *discoverable*: every workspace-aware skill
finds its workspace by looking for a manifest that claims the current repo, so a
workspace without one is invisible to all of them. The machinery that makes full tier
heavy is the sync script, the test suite, the git repo and the README, none of which
light tier gains.

Default to **Light** unless the operator wants the sync machinery or
plans to share it. Say which tier you're building and why, then build it. Light
workspaces upgrade later; the phases below are additive.

## Phase 2: Scaffold the directory

```bash
mkdir -p <root>/<name>-workspace/.claude/skills <root>/<name>-workspace/.claude/agents
```

### `CLAUDE.md` (both tiers: the whole point of the workspace)

Write the skeleton, then fill it in Phase 5:

```markdown
# <Name> Workspace

Multi-repo workspace for <one-line scope>. This file holds the cross-cutting
synthesis that lives in no single repo (<name the 2-3 actual themes>) plus an
index of the repos.

Each repo owns its own `CLAUDE.md`; edit those in place. They are **not**
imported here (eager imports load every repo's context on every session, which
is wasteful). Instead: **before working in a repo, read its `CLAUDE.md`.** The
repos are sibling directories of this workspace, and `.claude/settings.json`
adds each one, and its `-wt/` worktrees, as an allowed directory once you accept
the trust prompt. `repos.json` declares membership; a repo beside this one that
the manifest does not claim is not a member.

**Start every session here**, not in a member repo: a session opened in a member
repo gets none of this file.

## How changes land

**Code changes go in a worktree**, `../<repo>-wt/<slug>/`, one per task, and
every primary checkout stays on its default branch. This workspace follows the
rule too: its changes go in `../<name>-workspace-wt/<slug>/`.
<!-- Shared tier with a protected main: add "Every change to main is a reviewed
     pull request, docs included; a ruleset with no bypass enforces it." -->

## Repository index (read the repo's CLAUDE.md on demand)

| Repo | Path | What it is |
|---|---|---|
| <repo> | `../<repo>/CLAUDE.md` | <one line: language/framework + role in the system> |

<!-- For repos with no CLAUDE.md, point at the directory and say so:
     | <repo> | `../<repo>/` | <role>. No `CLAUDE.md` yet. | -->

## Cross-cutting notes

### <Theme, e.g. Local development & testing (cross-service)>

### <Theme, e.g. Cross-surface map>

A non-trivial change usually ripples across more than one of:

- **<repo>** (<what it is>): <when it's affected, and when it is explicitly NOT>

When vetting a story or PR, walk this list and decide affected/not-affected for each.

### <Theme, e.g. Data provenance (system-of-record → this app)>
```

Guidance that makes this file earn its keep:

- The **cross-surface map** is the highest-value section. For each repo, one line
  on *what kinds of change touch it*, including the negative case ("not an edit
  surface for frontend work"). This is what stops an agent from missing a ripple.
- **Provenance chains** get an ASCII arrow diagram plus the lag/failure
  characteristics of each hop, and a `(verified <YYYY-MM-DD>)` stamp.
- Mark anything **interim** as interim, with the story/PR that will undo it.
- Convert relative dates to absolute.

### `.claude/settings.json` (both tiers: how a session reaches the repos)

The member repos reach a session through the committed settings file, not
through launcher flags, so every teammate and every launch method (alias, IDE,
plain `claude`) gets the same access. One `../<repo>` and one `../<repo>-wt`
entry per `repos.json` row, plus the workspace's own `-wt`:

```json
{
  "permissions": {
    "additionalDirectories": [
      "../<name>-workspace-wt",
      "../<repo>",
      "../<repo>-wt"
    ]
  }
}
```

- **Relative paths resolve against the workspace's primary checkout**, which is
  why a session must start there: started in a workspace worktree, `../<repo>`
  resolves inside `<name>-workspace-wt/`.
- **Claude Code ignores this file until the folder is trusted.** The first
  `claude` in the workspace shows the trust prompt; say so in `README.md`.
- **The list is a copy of `repos.json`**, so it drifts. Phase 6 checks it, and
  in the full tier `scripts/check-setup.sh --settings-only` checks it on every
  pull request.
- If any member repo generates files holding live credentials (a decrypted
  config dump, a pulled `.env`), add a `permissions.deny` entry such as
  `"Read(//**/<that-dir>/**)"` and name the directory in `CLAUDE.md`.

### `.claude/skills/` and `.claude/agents/` (both tiers)

`.claude/skills/<skill>/SKILL.md` for workspace-scoped slash commands,
`.claude/agents/<agent>.md` for workspace-scoped subagents. Create the
directories empty; do not invent skills the operator did not ask for.

When the operator does want skills from a collection, **copy them in, one copy
of each**, rather than symlinking or relying on `~/.claude/skills`. A user-level
skill of the same name shadows the workspace's copy, so edits land in a file no
session loads; and a symlink into a personal clone is a file no teammate has.
Record where each came from (a `VENDORED.json` of `{skill, source, commit}` is
enough) so a later update has a baseline.

### Domain docs (both tiers, created when first needed)

The workspace owns the cross-repo `CONTEXT.md`, `docs/adr/` and `docs/agents/`.
Which level a given term, ADR or tracker config belongs at is the `workspaces`
skill's rule; do not pre-create empty files for it.

### Full tier only

**`.gitignore`** has three sections: local overrides, then one `/<repo>/` line
per member repo (leading slash = workspace root only), then misc. It carries no
personal paths (rule 3):

```gitignore
# Personal ignores belong in .git/info/exclude, not here.

# --- local overrides ---
repos.local.json
CLAUDE.local.md
*.local.*

# --- sibling member repos (each has its own git history) ---
/<repo>/
...

# --- misc ---
node_modules/
.DS_Store
.superpowers/
```

**`repos.json`**: the machine-readable companion to the index table.
`{name, slug, tier}` per repo, `tier` being `core` or `adjacent`, core block
first, columns aligned:

A shared workspace lists **itself** as the first `core` row: the sync script
then resolves that row to the workspace's own checkout, so one run refreshes the
workspace and its members together.

```json
{
  "repos": [
    { "name": "<name>-workspace", "slug": "<owner>/<name>-workspace", "tier": "core" },
    { "name": "<repo>", "slug": "<owner>/<repo>", "tier": "core" },

    { "name": "<repo>", "slug": "<owner>/<repo>", "tier": "adjacent" }
  ]
}
```

Note in `README.md` that personal repos and overrides go in `repos.local.json`
(gitignored, merged last, wins by name).

**`scripts/`**: **copy the scripts from `assets/`, don't write them**:

```bash
mkdir -p <root>/<name>-workspace/scripts
cp "$ASSETS"/sync-repos.sh "$ASSETS"/test-sync-repos.sh \
   "$ASSETS"/check-setup.sh "$ASSETS"/test-check-setup.sh <root>/<name>-workspace/scripts/
chmod +x <root>/<name>-workspace/scripts/*.sh
```

**`check-setup.sh`** is what a teammate runs first after cloning: tools present
and `gh` signed in, every `core` repo cloned, `.claude/settings.json` in step
with `repos.json`, and the trust prompt accepted. It is generic as shipped. When
the workspace depends on more (an MCP server its skills call, a runtime version,
a private registry), add those checks where its header says, in the same
`ok`/`warn`/`fail` shape, and a test case for each.

**`sync-repos.sh`** is workspace-agnostic (it reads `repos.json` relative to its own
location), so **no edits are needed**: only `README.md` has to describe it. It
encodes non-obvious hard-won behavior; preserve all of it:

- `unset CDPATH`: if the operator's shell exports `CDPATH`, `cd` echoes its
  resolved path to stdout and silently corrupts every `$(cd … && pwd)` capture.
  Keep the guard even on a machine where `CDPATH` is unset.
- clone destination resolved via `git rev-parse --git-common-dir`, so running
  from a linked worktree doesn't scatter duplicate clones
- bash 3.2 compatible (mac system bash): space-delimited name strings, no arrays
- never stashes, resets, checks out, or pushes; dirty/diverged repos are
  reported, not modified
- unborn HEAD and "checked out in another worktree" are warnings, not fatals

Then prove both work on this machine. The suites are hermetic (no network, no
real `gh`, no real clones), and each ends on a `N passed, 0 failed` line; any
other last line means the suite did not run to the end:

```bash
<root>/<name>-workspace/scripts/test-sync-repos.sh 2>&1 | tail -1
<root>/<name>-workspace/scripts/test-check-setup.sh 2>&1 | tail -1
```

**`.github/workflows/check-workspace.yml`**: copy `$ASSETS/check-workspace.yml`
there when the workspace will have a protected `main`. It runs the settings
check and both suites on every pull request; once it has run once, add it to
the ruleset as a required status check. Its `runs-on: ubuntu-latest` assumes
GitHub-hosted runners; an org that uses self-hosted ones names its own label.

**`README.md`**: quick start (clone → `./scripts/sync-repos.sh` → `claude` in
the workspace and **accept the trust prompt**, without which the member repos
are unreadable → `./scripts/check-setup.sh` → start every session there), the
layout/file table, the tier explanation, and requirements
(`git`, `gh` authenticated, `jq`; clone transport follows
`gh config get git_protocol`, so SSH or HTTPS both work).

**Git init**: `git -C <root>/<name>-workspace init` plus an initial commit.
Creating a *remote* is outward-facing and hard to reverse: **confirm org and
visibility with the operator first**, then
`gh repo create <org>/<name>-workspace --private --source=… --remote=origin`.
Never push without explicit go-ahead.

**Protect `main`** once the remote exists, if Phase 0 said yes. This is
outward-facing too, and it binds the operator as well, so show the ruleset and
apply it on a yes:

```bash
gh api -X POST repos/<org>/<name>-workspace/rulesets --input - <<'JSON'
{ "name": "main", "target": "branch", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [],
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" },
             { "type": "pull_request", "parameters": {
                 "required_approving_review_count": 1,
                 "dismiss_stale_reviews_on_push": true,
                 "require_code_owner_review": false,
                 "require_last_push_approval": false,
                 "required_review_thread_resolution": false } } ] }
JSON
```

A solo operator cannot approve their own PR, so a one-person workspace sets
`required_approving_review_count` to `0`: the PR still exists as the review
record. Rulesets on a private repo need a paid plan; if the call returns 403 or
404 for that reason, report it rather than retrying. From here on, every change
to the workspace, including finishing this scaffold, goes through a worktree
and a PR.

## Phase 3: Clone the member repos

Full tier: `<root>/<name>-workspace/scripts/sync-repos.sh --print` first (shows
the resolved manifest; no writes, no auth needed), then run it for real, `--all`
if the adjacent tier is wanted too. Report the summary verbatim. Marks: `✓` up
to date, `↓` fast-forwarded, `+` cloned, `!` needs attention (dirty, on a
feature branch, or diverged, all informational: **never** offer to stash or reset),
`✗` clone/fetch failed (usually no access to that org, or a stale slug).

Light tier, or repos already present: verify each exists and note which are
missing:
`for r in <repos>; do git -C <root>/$r rev-parse --abbrev-ref HEAD 2>&1; done`.
Do not clone repos the operator did not ask for.

## Phase 4: Wire up the shell rc file

This is the part that makes the workspace usable. `RC` below is the file
resolved in Phase 0 (`~/.zshrc`, `~/.bashrc`, …); `SH` is `zsh` or `bash`.

**4a. Back up and inspect.**

```bash
cp "$RC" "$RC.bak.$(date +%Y%m%d-%H%M%S)"
grep -n "^alias cc-\|_REPOS=\|^[a-z-]*-\(rg\|cd\|find\)()\|^alias g[a-z]\{2,5\}=" "$RC"
```

**4b. Check for name collisions, against the live shell, not just the file.**
The Phase 4a `grep` only sees `$RC` itself. Aliases and functions also arrive
from oh-my-zsh, plugin managers, `$ZSH_CUSTOM`, `/etc/zshrc`, and anything `$RC`
sources, so a grep-clean name can still collide. Ask the shell instead:

Probe by **exit status, never by parsing output**, since an rc that prints anything to
stdout (motd, oh-my-zsh update notice, version manager banner) would otherwise
produce false collisions on every name:

```bash
probe() { $SH -ic "$1 $2 >/dev/null 2>&1" >/dev/null 2>&1; }
for n in cc-<name> cc-<name>-c cc-<name>-r g<abbrev>; do
  probe alias "$n" && echo "COLLISION: alias $n"
done
for f in <name>-rg <name>-find <name>-cd; do
  probe type "$f" && echo "COLLISION: $f"
done
$SH -ic 'echo ${<NAME>_REPOS:-unset}' 2>/dev/null | tail -1   # want "unset"
```

(Verified in both zsh and bash, and verified immune to stdout noise.)

Both shells silently redefine on collision, so a clash breaks an *existing*
workspace with no error at all. **Run this before writing anything.** If a name
is taken, pick another rather than shadowing it; if the collision is in a
file you don't control (a plugin), renaming yours is the only safe move.

**4c. Append a new section** at the end of the workspace blocks (matching the
file's existing `## <Name>` shape if it has one). Substitute `<name>`, `<NAME>`,
`<root>`, and the member-repo list:

```sh
## <Name>

# <Name> workspace launcher (repo access comes from .claude/settings.json)
alias cc-<name>='cd <root>/<name>-workspace && claude --model "opus[1m]" --effort xhigh'

alias cc-<name>-c='cc-<name> --continue'
alias cc-<name>-r='cc-<name> --resume'

# cd shortcuts (skip any abbrev already defined elsewhere in this file)
alias g<abbrev>='cd <root>/<repo>'

# Workspace-scoped search (needs rg, fd, fzf, bat, eza; omit if not installed)
<NAME>_REPOS="$HOME/github/<repo-1> $HOME/github/<repo-2> $HOME/github/<repo-n>"

<name>-rg() { rg "$@" $(echo $<NAME>_REPOS); }
<name>-find() {
  local file
  file=$(fd . $(echo $<NAME>_REPOS) | fzf --preview 'bat --color=always --line-range=:300 {}')
  [ -n "$file" ] && ${EDITOR:-vi} "$file"
}
<name>-cd() {
  local dir
  dir=$(fd --type d --max-depth 4 . $(echo $<NAME>_REPOS) \
    | fzf --preview 'eza --tree --level=2 --git-ignore --color=always {}')
  [ -n "$dir" ] && cd "$dir"
}
```

Notes on the template, so you don't "fix" it into something broken:

- No `--add-dir` flags: `.claude/settings.json` carries the member repos for
  every launch method, and a second list in the alias is one more copy to drift.
- `--model "opus[1m]"` is quoted because `[` `]` are glob characters in zsh.
  Drop `[1m]` and/or `--effort xhigh` if Phase 0 showed they aren't available.
- `$(echo $<NAME>_REPOS)` is deliberate word-splitting of the path string.
  Don't "correct" it to `"$<NAME>_REPOS"`, which passes one glued argument.
- `<NAME>_REPOS` uses `$HOME/...` (not `~`) because tilde doesn't expand inside
  the quoted string. If `<root>` isn't `$HOME/github`, adjust it there too.
- Adjacent repos read only on demand can be left out of `<NAME>_REPOS` to keep
  searches fast; they stay readable through `.claude/settings.json`.

**4d. Syntax-check, then verify in a subshell.**

```bash
$SH -n "$RC" && echo "syntax OK"
$SH -ic 'alias cc-<name>; type <name>-rg' 2>&1 | head
```

A syntax error here breaks every new shell, so **never skip the `-n` check**.
Tell the operator to run `source "$RC"` (or open a new tab) themselves; a
`source` inside a tool call doesn't affect their shell.

**4e.** If `-n` fails, restore the backup immediately and report. Otherwise say
where the backup is and let them delete it.

## Phase 5: Populate `CLAUDE.md` for real

The skeleton is worthless until it carries verified cross-cutting facts.

**First, confirm you're reading current code.** A stale clone produces a
confidently wrong `CLAUDE.md`, the same failure as inventing facts, just with a
plausible source. Check every repo before you read any of it:

**Resolve each repo's default branch, never hardcode `main`.** `master` is still
common, and `rev-list HEAD..origin/main` on a `master` repo prints *nothing* and
exits quietly, so the check silently passes on exactly the repo it should have
caught (observed: a repo reporting `behind by []` that was really 20 behind):

```bash
for r in <repos>; do
  git -C <root>/$r fetch -q origin
  db=$(git -C <root>/$r symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
  printf '%-28s default=%-8s behind by %s\n' "$r" "${db:-?}" \
    "$(git -C <root>/$r rev-list --count "HEAD..origin/${db:-HEAD}" 2>/dev/null || echo '?')"
done
```

A `?` in either column means resolve it before reading anything from that repo.
(`scripts/sync-repos.sh` already resolves the default branch per repo this way;
this loop is the read-only equivalent for the light tier.)

A repo behind by more than a handful of commits is not a valid source. Full tier:
`./scripts/sync-repos.sh` fast-forwards the clean ones. For a repo it *can't*
advance (dirty, diverged, on a feature branch), read through the remote ref
instead of the working tree: `git -C <root>/<repo> show origin/main:<path>` and
`git -C <root>/<repo> ls-tree -r --name-only origin/main`, and never pull or
merge someone's checkout to make your own discovery easier.

*(Observed for real: a member repo 31 commits and ~7 weeks behind, `package.json`
at `0.1.0` locally versus `0.6.1` on `main`.)*

Then, for each member repo: read its `CLAUDE.md` (or `README.md` + entry point +
`package.json`/`go.mod`/`pyproject.toml` if it has none), and skim
`git -C <root>/<repo> log --oneline -20 origin/main` for what's actually in
motion. **Locate files with `git ls-files`/`ls-tree`, not shell globs**, since an
unmatched glob aborts the whole command in zsh and passes through literally in
bash, so a file that exists gets reported missing. Then write:

- the **index table**: one accurate line per repo (language/framework + role)
- the **cross-surface map**: which changes touch which repo, incl. the negatives
- any **provenance chain** you can trace end to end, with a verified date and
  the fail-open/fail-soft behavior of each hop
- **shared contracts**: event names, envelope versions, config keys that must
  exist in more than one place

Where you couldn't verify something, leave it out or mark it explicitly
(`unverified`, `hypothesis`). A short honest file beats a long speculative one;
it grows as work happens.

## Phase 6: Verify and report

Run these and show the operator the actual output:

```bash
ls -a <root>/<name>-workspace
$SH -n "$RC" && echo "rc OK"
$SH -ic 'alias cc-<name>'
git -C <root>/<name>-workspace status --short
```

Full tier: run `<root>/<name>-workspace/scripts/check-setup.sh` and show its
output. Before the operator has opened Claude Code there, the trust line fails;
that is expected, and the report says so.

Light tier has no scripts, so check `settings.json` against `repos.json` inline
(both directions; `settings OK` is the only passing output):

```bash
ws=<root>/<name>-workspace
diff <( { echo "../<name>-workspace-wt"; jq -r --arg s "<name>-workspace" '.repos[].name | select(. != $s) | "../\(.)", "../\(.)-wt"' "$ws/repos.json"; } | sort -u) \
     <(jq -r '.permissions.additionalDirectories[]' "$ws/.claude/settings.json" | sort -u) && echo "settings OK"
```

Then report: tier built, files created, repos cloned vs already present vs
missing, the rc section added and its aliases, and anything deliberately left to
the operator (remote repo creation, `source "$RC"`, missing tools, unverified
`CLAUDE.md` sections).

## Upgrading an existing light workspace to full

Same phases, additive: `.gitignore` → `repos.json` (derive slugs from the
existing siblings' `origin` remotes) → `.claude/settings.json` → copy `scripts/`
from `assets/` → `README.md` → `git init` + first commit. The existing
`CLAUDE.md` and `.claude/` stay as they are; add the index table and the
*How changes land* section only if missing. If `.gitignore` hides
`.claude/agents/` or `docs/`, ask before un-ignoring: committing them shares
whatever is in there.

Check the rc block against Phase 4's template and bring it up to shape: move
any `--add-dir` list into `.claude/settings.json` and drop it from the alias,
and add the `-c`/`-r` aliases and search helpers if absent. Do not renumber,
reorder, or reformat the operator's other blocks.
