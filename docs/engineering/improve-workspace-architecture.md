# improve-workspace-architecture

## What it does

`improve-workspace-architecture` surveys a set of repos you work across and reports
where the friction between them lives: one concept implemented twice, a seam that
ended up in the wrong repo, a contract whose caller and implementation sit on
opposite sides of a boundary with nothing shared between them, a package whose
consumers change every time it does.

It ignores everything inside a single repo, however bad. That is the constraint that
makes it useful: [improve-codebase-architecture](./improve-codebase-architecture.md)
already finds shallow modules, and a survey that reported both would bury one rare
cross-repo finding under thirty ordinary ones. Scope, not depth, is what separates
the two.

## When to reach for it

You invoke this by typing `/improve-workspace-architecture`, and the agent won't
reach for it on its own.

Reach for it when a change keeps rippling: the same ticket touches three repos every
time, or a fix has to land twice because two repos carry the same logic. For friction
inside one repo, use [improve-codebase-architecture](./improve-codebase-architecture.md)
instead. If no workspace claims the repo you are in, this skill says so and stops
rather than guessing at a repo set.

## Prerequisites

A workspace: a directory holding a `repos.json` manifest whose entries include the
repo you are in, with member repos as siblings on disk. That layout is what
[new-workspace](./new-workspace.md) builds, and the manifest is what the survey reads
to know its scope. `git` and `jq` are needed; the report needs a browser.

Nothing is written to any repo. The report goes to the OS temp directory.

## Co-change is the signal, not size

A single repo has one history, so `git log` shows you hot spots. A workspace has one
history per repo and none for the set, and the replacement is better than the thing it
replaces: **two repos that keep changing together have a seam in the wrong place.**

The survey groups commits across repos by the ticket id their subjects and branches
carry, ranks pairs of repos by how often they appear together, and looks there first.
That ranking is the whole attention model. A pair co-changing under many tickets is
not a coincidence, it is a boundary in the wrong position, and it points at a specific
pair of files rather than a vague sense that two services are "coupled".

## Two axes, never merged

Each candidate is scored twice. **Locality** is how much of the fix lands inside one
repo. **Choreography** is how much coordination it needs: how many repos change, in
what order, across how many review queues, whether a deploy order is implied.

They are reported side by side and never blended into one ranked list, because a
candidate routinely scores well on one and badly on the other. Extracting a shared
core inside one repo is high Locality. Making the second repo consume it is pure
Choreography: two PRs, two queues, a deploy order. A single "Strong recommendation"
badge hides the second half, and the second half is where cross-repo work actually
goes wrong.

## Common questions

**Why two skills instead of one that notices it's in a workspace?**

Because almost nothing is shared. The unit is different (friction between repos, not a
shallow module), the attention signal is different (co-change across histories, not
one `git log`), the domain inputs are different (workspace glossary and manifest, not
a repo's), and the output has two axes instead of one ranked list. Branching inside
one file would give you two skills wearing one name, and the router can send you to
the right one in a sentence.

**It told me my cross-repo doc was wrong. Is that its job?**

Yes, and it is often the most valuable thing it produces. A document describing how
several repos relate is the least-verified artifact in a workspace, because no single
repo's tests or reviews cover it. The survey confirms every claim it carries against
the code and reports the contradictions it finds, separately from the refactor
candidates, because a doc fix is worth landing even when the refactor never happens.

**Why does it refuse to look at problems inside one repo?**

Volume. Cross-repo candidates are rare and expensive to act on; intra-repo ones are
common and cheap. Mixing them means the list is dominated by the cheap kind and the
rare kind stops getting read. Run the sibling skill in the repo and you get those,
ranked among their peers where they belong.

## It's working if

- Every candidate names files in at least two repos. One that does not is the sibling
  skill's job, and its presence means the scope leaked.
- The candidates you recognise as real problems appear near the top, because the
  co-change ranking found them rather than you naming them.
- At least one candidate has a high score on one axis and a low one on the other. If
  every candidate scores the same on both, the axes are not being assessed
  independently.
- Counts in the report match `git ls-files`, not a `find`. A candidate inside
  `node_modules` or a build directory means the file lists were gathered wrongly.

## Where it fits

`improve-workspace-architecture` is **periodic maintenance** one level above the
repo, the survey you run when a rippling change makes you suspect a boundary is
wrong. Its neighbour is [improve-codebase-architecture](./improve-codebase-architecture.md),
which is the same motion inside one tree; between them the split is scope. Both feed
the main flow the same way: picking a candidate generates an idea to take into
[grill-with-docs](./grill-with-docs.md), and [codebase-design](./codebase-design.md)
is the bench you design the chosen seam on.
[new-workspace](./new-workspace.md) defines the layout this reads, so a workspace
scaffolded by that skill is surveyable by this one with no further setup. For which
skill to reach for next, [which-skill](./which-skill.md) routes the whole set.
