---
name: workspaces
description: "Vocabulary and resolution rules for multi-repo workspaces: what a workspace, member repo and cross-repo unit of work are, how to find the workspace that claims the repo you are in, and which of the workspace's or the repo's CONTEXT.md, docs/adr/ and docs/agents/ a given artifact belongs to. Use when a skill reads a repo-local doc, writes an artifact that could span repos, or judges a unit of work that could span repos."
---

# Workspaces

A **workspace** is a thin coordination directory holding what belongs to a *set* of
repos rather than to any one of them. This skill is the vocabulary layer underneath
the workspace-aware skills: reach for it when you need the terms or the resolution
rules, not the process. Scaffolding a workspace is `new-workspace`; surveying one is
`improve-workspace-architecture`.

## Does your skill need this?

Only some do. A skill needs workspace routing when it does at least one of:

1. **Reads a repo-local doc.** `CONTEXT.md`, `docs/adr/`, `docs/agents/`. In a
   workspace the authoritative copy may be one level up.
2. **Writes an artifact that could span repos.** A glossary term, an ADR, a research
   file, a tracker config. Writing it into one member repo hides it from the others.
3. **Judges a unit of work that could span repos.** A story whose acceptance criteria
   are satisfied across several PRs, a ticket that lands in more than one repo.

**None of the three, no routing.** Roughly half the skills in this collection have no
workspace-shaped decision at all, and for those a probe is a no-op that costs load on
every single-repo run. This mirrors the hard/soft dependency split in
`.agents/adr/0001`: a skill that produces *wrong* output without the workspace must
route, one that is merely less sharp may wait until it bites.

## Language

**Workspace**:
A coordination directory holding the material that belongs to a set of repos rather
than to one of them. It never contains the repos.
_Avoid_: monorepo (one git root, the opposite shape), project, umbrella repo

**Member repo**:
A repo a workspace claims, living as its **sibling** on disk with its own git history
and its own `CLAUDE.md`.
_Avoid_: subrepo, submodule, package (all imply containment)

**Core repo** / **Adjacent repo**:
A member the team owns and changes, versus one it reads from or is affected by but
does not own. The manifest's `tier` is the authority.
_Avoid_: "the repos" used loosely, which is how three lists end up disagreeing

**Cross-repo unit of work**:
One story, ticket or change whose completion spans more than one member repo, and so
more than one PR. Common rather than exceptional in an active workspace.
_Avoid_: multi-repo change (describes the diff, not the unit), epic (a tracker noun)

**Sibling PR**:
Another PR implementing the same cross-repo unit of work, in a different repo. The
term earns its place by fixing a bug class: a review that judges one PR against the
whole unit reports the siblings' requirements as *missing* when they are merely
*elsewhere*.
_Avoid_: related PR (too weak), stacked PR (a dependent branch)

## Finding the workspace that claims a repo

Run the script; it prints the workspace path, or nothing with exit 1:

```bash
find-workspace.sh [<repo-dir>]        # default: the current directory
```

Resolve it the way any asset in this collection is resolved, then branch on the exit
status. **Nothing found is not an error**: it means single-repo, and the skill should
carry on with its single-repo behaviour and say nothing about workspaces.

```bash
for d in ~/.claude/skills/workspaces/assets .claude/skills/workspaces/assets; do
  [ -d "$d" ] && FW="$d/find-workspace.sh" && break
done
ws="$(bash "$FW" 2>/dev/null)" || ws=""
```

It keys on **the manifest claiming this repo**, never on directory adjacency: a
`repos.json` whose `repos[].slug` includes the repo's `origin` slug. Adjacency would
be wrong, because an unrelated repo sitting beside the clones is not a member, and
with several workspaces as siblings of many repos adjacency cannot disambiguate at
all. A linked worktree resolves beside its primary checkout rather than beside
itself.

Both workspace tiers carry a manifest, so light and full are equally discoverable. A
workspace with no `repos.json` predates that rule and is invisible to every
workspace-aware skill; adding one is the fix, and it is a data file, not machinery.

## Which copy does an artifact belong to?

One rule, applied to each artifact: **material that spans repos belongs to the
workspace; material intrinsic to one repo belongs to that repo.** The corollaries are
what skills actually need:

| Artifact | Lives in |
| --- | --- |
| A glossary term used in more than one repo | the workspace `CONTEXT.md` |
| A glossary term meaningful only inside one repo | that repo's `CONTEXT.md` |
| A decision constraining several repos | the workspace `docs/adr/` |
| A decision about one repo's internals | that repo's `docs/adr/` |
| Tracker, triage and label config | the workspace `docs/agents/`, once, when the values do not vary by repo |
| Research spanning repos | the workspace |

**Read wider than you write.** When resolving vocabulary, read the workspace glossary
*and* the member repo's, with the repo's winning on a genuine conflict, since it is
closer to the code. When writing, pick exactly one home by the rule above: a term
written to both drifts, and a term written to one member repo is invisible to the
others.

Create these lazily. A workspace with no `CONTEXT.md` or `docs/adr/` is the normal
starting state, not a misconfiguration.

## Say which one you used

A skill that resolved a workspace should state it in its output, in a line, naming
the path and what it read from there. A reader cannot otherwise tell whether a
glossary term was missing or merely looked for in the wrong place, and that ambiguity
is what makes a wrong answer here expensive to diagnose.
