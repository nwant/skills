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
and its own `CLAUDE.md`. Membership is **many-to-many**: one repo belonging to several
workspaces is normal rather than a misconfiguration, because a repo can host work for
more than one programme. Which workspace is in effect is resolved by working
directory first, and is genuinely ambiguous otherwise.
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

## Resolving the workspace in effect

Run the script. It has **three** outcomes, and the third is the one callers forget:

```bash
find-workspace.sh [<dir>]     # default: the current directory
# exit 0  one workspace, path on stdout
# exit 1  none, no output
# exit 2  ambiguous, every claimant on stdout, one per line
```

```bash
for d in ~/.claude/skills/workspaces/assets .claude/skills/workspaces/assets; do
  [ -d "$d" ] && FW="$d/find-workspace.sh" && break
done
out="$(bash "$FW" 2>/dev/null)"; rc=$?
case "$rc" in
  0) ws="$out" ;;                      # use it
  1) ws="" ;;                          # single-repo run, say nothing about workspaces
  2) ws="" ;;                          # ASK: name the claimants and let the user pick
esac
```

**Exit 1 is not an error.** It means single-repo, and the skill should carry on with
its single-repo behaviour without mentioning workspaces at all.

**Exit 2 must ask, never guess.** Name the claimants and let the user choose. Picking
one silently is how a term meant for one workspace's glossary gets written into
another's, or a PR gets reviewed against the wrong set of standards.

### The two resolution steps

1. **Are we already inside a workspace?** Walk up from the directory looking for one
   that holds a `repos.json`. Standing in a workspace is unambiguous, needs no git and
   no remote, and is how a workspace session normally starts, so it answers first and
   answers alone. This is why a light-tier workspace, which is not a git repo, still
   resolves.
2. **Which workspaces claim this repo?** Scan the repo's siblings for a `repos.json`
   whose `repos[].slug` includes the repo's `origin` slug. Keying on the manifest
   rather than on directory adjacency is the point: an unrelated repo beside the
   clones is not a member, and several workspaces can sit beside many repos, so
   adjacency cannot disambiguate at all. A linked worktree resolves beside its primary
   checkout rather than beside itself.

Step 1 beats step 2 deliberately. Once you are standing in a workspace there is
nothing to disambiguate, which is what makes overlapping membership a non-issue on the
normal path.

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

**A palette can be unioned; a judgment cannot.** This is the rule that decides what to
do when more than one workspace claims the repo, and it is not the same for everything
a skill reads.

*Palettes* widen safely. Vocabulary, prior art, research context: read the workspace
glossary **and** the member repo's, and every claimant's when several claim it, because
more of a palette only helps. On a genuine conflict the repo's wins, being closer to the
code.

*Judgments* select one authority and must be chosen, never merged. Coding standards,
acceptance criteria, tracker and label config: applying two workspaces' standards to one
diff is how a change gets judged against rules its programme does not follow. When the
resolution is ambiguous, **ask which workspace** rather than unioning them.

Writing is always a judgment: pick exactly one home by the rule above. A term written
to both drifts, and a term written to one member repo is invisible to the others.

Create these lazily. A workspace with no `CONTEXT.md` or `docs/adr/` is the normal
starting state, not a misconfiguration.

## Say which one you used

A skill that resolved a workspace should state it in its output, in a line, naming
the path and what it read from there. A reader cannot otherwise tell whether a
glossary term was missing or merely looked for in the wrong place, and that ambiguity
is what makes a wrong answer here expensive to diagnose.
