# workspaces

## What it does

`workspaces` is the vocabulary layer the multi-repo skills sit on. It defines the
terms (workspace, member repo, core versus adjacent, cross-repo unit of work, sibling
PR), ships a tested script that finds the workspace claiming the repo you are in, and
states which copy of `CONTEXT.md`, `docs/adr/` or `docs/agents/` a given artifact
belongs to.

It answers one question in three places rather than three questions: **material that
spans repos belongs to the workspace, material intrinsic to one repo belongs to that
repo.** Every corollary a skill needs falls out of that, which is why the rule is
stated once here instead of being re-derived by each skill that trips over it.

## When to reach for it

Model-invoked: a skill calls it, or you can type `/workspaces` to read the rules
yourself. It is a reference, not a flow, so it never does anything on its own.

The test for whether a skill needs it is deliberately narrow. A skill routes through
`workspaces` when it **reads a repo-local doc**, **writes an artifact that could span
repos**, or **judges a unit of work that could span repos**. None of those three, no
routing: roughly half the skills in this collection have no workspace-shaped decision,
and for them the check costs load on every single-repo run and changes nothing.

## Prerequisites

`git` and `jq`, for the probe. Nothing else, and nothing is written.

A workspace is discoverable only if it has a `repos.json` listing its members' slugs.
Both tiers carry one, so a workspace built by [new-workspace](./new-workspace.md) is
discoverable either way; one predating that rule is invisible until a manifest is
added.

## Discovery keys on the manifest, not on adjacency

The probe looks for a sibling directory holding a `repos.json` whose `repos[].slug`
includes this repo's `origin` slug. The distinction matters more than it sounds:
"is a sibling of" would wrongly claim any unrelated repo sitting beside the clones,
and once several workspaces are siblings of many repos, adjacency cannot disambiguate
at all. Keying on the manifest means a workspace has to *claim* a repo to own it.

Finding nothing is a normal answer, not an error. The script exits 1 silently and the
caller carries on as a single-repo run, which is what keeps every workspace-aware
skill correct outside a workspace.

## A palette can be unioned; a judgment cannot

This is the rule that decides what happens when more than one workspace claims a repo,
which is normal rather than exceptional: membership is many-to-many.

*Palettes* widen safely. Vocabulary, prior art, research context: read every claimant's,
because more of a palette only helps, and let the repo's own copy win a genuine conflict
since it sits closer to the code.

*Judgments* select one authority. Coding standards, acceptance criteria, tracker config:
applying two workspaces' standards to one diff judges a change against rules its
programme does not follow. Ambiguity there is a question to ask, not a set to merge.

Writing is always a judgment, so it always picks exactly one home. A term written to
both drifts apart; a cross-repo term written into one member repo is invisible to the
others.

## Common questions

**Why a separate skill instead of putting the probe in `new-workspace`?**

`new-workspace` is user-invoked, so no other skill can be told to call it, and skills
would have to hardcode a path like `~/.claude/skills/new-workspace/assets/...`, which
is wrong on Codex and on any other harness. A model-invoked skill is the collection's
existing way to share reference material, which is exactly what
[codebase-design](./codebase-design.md) does for the deep-module vocabulary.

**Why does the manifest live in light-tier workspaces, which have no scripts?**

Because the manifest is data, not machinery, and it is the only thing that makes a
workspace discoverable. Gating it behind the full tier meant every workspace someone
built solo was invisible to all the workspace-aware skills. The weight of full tier is
the sync script, its test suite, the git repo and the README, none of which light tier
gains.

**My workspace isn't found.**

It has no `repos.json`, or the manifest does not list this repo's `origin` slug.
Check the slug the probe computes against the manifest's entries; the `git@host:` and
`https://` remote forms both normalise to `owner/repo`, so a mismatch is usually a
missing or misspelled entry rather than a URL-form problem.

## It's working if

- Running the probe in a member repo prints the workspace path, and running it in an
  unrelated repo beside the same workspaces prints nothing and exits 1.
- A skill that resolved a workspace says so in its output, naming the path and what it
  read from there.
- A cross-repo glossary term appears in exactly one `CONTEXT.md`, the workspace's.
- Skills with no workspace-shaped decision never mention workspaces at all.

## Where it fits

`workspaces` is a **vocabulary layer underneath** the other skills, reached by a
pointer rather than run as a step, the same shape as
[codebase-design](./codebase-design.md). Its neighbours are the two skills that own
workspace *process*: [new-workspace](./new-workspace.md), which builds the layout this
depends on, and
[improve-workspace-architecture](./improve-workspace-architecture.md), which surveys a
workspace for friction between repos. The skills that route through it are the ones
with a real decision to make, currently
[setup-skills](./setup-skills.md), [two-axis-review](./two-axis-review.md),
[domain-modeling](./domain-modeling.md) and `wait-what`.
[implement](./implement.md) deliberately does not: its guard is about reading the
ticket, which names its repo regardless of how many workspaces claim it. For which skill to reach for next, [which-skill](./which-skill.md) routes
the whole set.
