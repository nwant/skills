# new-workspace

## What it does

`new-workspace` builds a thin coordination directory for a set of repos you work
across: a `CLAUDE.md` holding the facts that span them, an index of the members, and
optionally a `repos.json` manifest, a sync script, and shell shortcuts for opening and
searching the set.

The workspace never contains the repos. They stay siblings on disk, each with its own
git history and its own `CLAUDE.md`, and the workspace file **points at** them rather
than importing them. That is the whole design: an eager `@`-import would pull every
repo's full context into every session, which is the cost the pattern exists to avoid.
What lands in the workspace is only what belongs to no single repo.

## When to reach for it

You invoke this by typing `/new-workspace`, and the agent won't reach for it on its
own. It writes directories and edits your shell rc file, which is not something to
fire autonomously.

Reach for it when work genuinely spans several repos and the cross-repo facts have
nowhere to live: a change that ripples across four services, a data path you keep
re-deriving, a local-dev chain no single repo documents. For a single repo, you want
nothing here: put the facts in that repo's own `CLAUDE.md`. For configuring a repo
that already exists, use [setup-skills](./setup-skills.md) instead.

## Prerequisites

It writes outside the current directory, which is unusual for a skill here:

| It writes | Where |
| --- | --- |
| The workspace itself | `<root>/<name>-workspace/`, beside your clones |
| A launcher, cd shortcuts, search helpers | your shell rc file, appended as one section |
| Member repo clones | `<root>/<repo>/`, on the full tier only |

`git` is always needed. The full tier's sync script also needs `gh`, `jq` and
`column`, and the optional search helpers need `rg`, `fd`, `fzf`, `bat` and `eza`. The
skill checks for all of them up front and reports what is missing with the right
installer, rather than emitting shortcuts that fail when you first call them.

`gh` must be authenticated to the host your repos actually live on. An unauthenticated
enterprise host makes every clone fail as "no access, or wrong slug", which reads like
a bad manifest and sends you debugging the wrong thing.

## Two tiers, and the default is the small one

**Light** is a `CLAUDE.md` and a `.claude/` directory. No git repo, no manifest, no
scripts. It fits solo work on repos you have already cloned.

**Full** adds a `README.md`, `repos.json`, `scripts/sync-repos.sh` with its test
suite, a `.gitignore`, and its own git repo. It earns its weight when teammates will
clone the workspace, or the repo set is large enough that one-command clone-and-refresh
saves real time.

Light is the default, and the phases are additive, so a light workspace upgrades in
place later. Running the skill against an existing ad-hoc workspace does exactly that
upgrade rather than starting over.

## The manifest is the thing that rots

`repos.json` and the index table in `CLAUDE.md` list the same repos, and nothing
enforces that they agree. A repo added to one and not the other is the failure mode
this pattern actually hits: the sync script silently skips a repo nobody notices is
missing, or the index promises a repo that was never cloned. Both change together or
neither does.

The same applies to the workspace file itself. Its value is that a reader trusts it,
so a cross-cutting claim goes in only when it was verified against the code, git
history, or config in front of you. A workspace `CLAUDE.md` full of plausible-sounding
fiction is worse than an empty one, because the reader has no way to tell which half
is which.

## Common questions

**Is this for a monorepo?**

No, the opposite. A monorepo already has one root, one history, and one place for
shared facts. This is for repos that are genuinely separate, deploy separately, and
have separate histories, but that you nonetheless change together. If your packages
live under one `git` root, you do not need a workspace.

**It edited my shell rc file. What exactly did it add?**

One appended section, backed up first, containing a launcher function, `cd` shortcuts,
and optionally search helpers. It never reflows or tidies the blocks already there,
and it syntax-checks before you source anything. It also probes the live shell for
name collisions rather than grepping the file, because an rc file that sources other
files can define a name the grep never sees.

**My repos are already cloned. Does it re-clone them?**

No. It verifies each one exists and reports which are missing, and it clones only
repos you asked for. Existing clones are left as they are, including dirty ones and
ones on feature branches: the sync script reports those for you to deal with and never
offers to stash or reset.

## It's working if

- The workspace `CLAUDE.md` contains nothing you could have found by reading one
  repo. Every line in it spans at least two.
- Opening the workspace gets you every member repo's context on demand and none of it
  up front.
- On the full tier, a fresh clone plus one script run produces the whole repo set, and
  a second run reports everything already up to date.
- Adding a repo to the set is one edit to `repos.json` and one row in the index,
  changed in the same commit.

## Where it fits

`new-workspace` is **run-once setup**, off every flow: it builds the place the flows
run in rather than being a step in one. Its neighbour is
[setup-skills](./setup-skills.md), which does the same job one level down, configuring
a single repo where this configures a set of them; run this first when the workspace
does not exist yet, then that inside each repo. The cross-repo `CLAUDE.md` it produces
is what makes [research](./research.md) and
[improve-codebase-architecture](./improve-codebase-architecture.md) useful across
repos rather than inside one. For which skill to reach for next,
[which-skill](./which-skill.md) routes the whole set.
