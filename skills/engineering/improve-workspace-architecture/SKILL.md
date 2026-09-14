---
name: improve-workspace-architecture
description: "Survey a multi-repo workspace for friction between repos: one concept implemented twice, a seam in the wrong repo, a contract straddling two, a shared package whose consumers churn with it. Reports candidates on two axes, what is fixable inside one repo and what needs coordinated change, then grills through whichever one you pick."
disable-model-invocation: true
---

# Improve Workspace Architecture

Surface architectural friction **between** repos in a workspace, and propose where a
seam belongs. This is the sibling of `improve-codebase-architecture`, which surveys
one tree: run that one inside a repo, and this one across a set of them.

Everything here is cross-repo by construction. A shallow module inside a single repo
is not a candidate no matter how bad it is, because the other skill already finds
those and burying one rare cross-repo finding under thirty ordinary ones is how a
survey stops being read.

Call the Skill tool with "codebase-design" for the architecture vocabulary
(**module**, **interface**, **depth**, **seam**, **adapter**, **leverage**,
**locality**) and use those terms exactly.

## Process

### 1. Find the workspace and its inputs

You may be started from the workspace or from a member repo. Resolve it either way:
a workspace is a directory holding a `repos.json` whose `repos[].slug` includes this
repo's `origin` slug. The layout and the canonical probe are defined by the
`new-workspace` skill. Key on the manifest claiming this repo, never on directory
adjacency: an unrelated repo sitting beside the clones is not a member.

If no workspace claims this repo, say so and stop. Point the user at
`/improve-codebase-architecture` instead; there is nothing for this skill to do in a
single repo.

Read, in this order:

- `repos.json`, for the member set and their tiers. **`core` is the survey scope.**
  Tiered-`adjacent` repos are read for context when a candidate touches them, but a
  candidate that lives entirely in repos nobody on this team owns is not actionable.
- The workspace `CONTEXT.md`, the glossary for naming seams, and `docs/adr/` for
  decisions not to re-litigate.
- The workspace `CLAUDE.md`, especially any cross-surface map, for where the author
  believes the seams are.
- Each involved repo's `CLAUDE.md`, as a **stand-in for a `CONTEXT.md` it probably
  does not have**. Treat it as unverified prose, not a glossary.

**Distrust all of it.** A cross-repo doc is the least-verified document in any
workspace, because no single repo's tests or reviews cover it. Every claim you carry
into a candidate must be confirmed against the code: a module path, a duplication, a
flag's value, a disabled listener. State the contradiction in the report when the doc
and the code disagree; that finding is often worth more than the candidate it came up
under.

### 2. Rank by co-change, not by size

A single repo has one history whose hot spots you can read off `git log`. A workspace
has one history per repo and none for the set, so the signal is different and better:
**two repos that keep changing together have a seam in the wrong place.**

Over a recent window (start with 90 days), collect per repo:

```bash
git -C <repo> log --since='90 days ago' --format='%H%x09%s%x09%cI'
git -C <repo> ls-files            # the file list, always; never find(1)
```

Group commits across repos by the **ticket id** their subjects and branch names carry,
and rank pairs of repos by how often they appear together. That ranking is your
attention order. A pair that co-changes under many ids is where to look first.

**Use `git ls-files` or `git ls-tree` for every file list and every count, never
`find` or a shell glob.** Vendor directories, build output, coverage and agent
worktrees differ per repo, and a `find`-based count can be off by more than an order
of magnitude. A survey that reports a candidate inside `node_modules` discredits
itself entirely.

### 3. The four candidate classes

Look for these and nothing else. Each has a detector, so the survey is evidence-led
rather than impressionistic:

1. **One concept implemented twice.** The same exported names, or near-identical
   files, in two repos. Detector: compare `git ls-files` basenames across the
   co-changing pair, then diff the collisions. Report what has already **diverged**,
   which is usually the story: two copies nobody syncs are not duplication, they are
   a silent fork.
2. **Seam in the wrong repo.** Files in different repos that co-change under the same
   ticket id, repeatedly. Detector: the ranking from step 2, drilled to file level.
3. **Straddling contract.** A caller in one repo whose only implementation is in
   another, with no shared type, schema or generated client between them. Detector:
   a client module naming a remote service, with no corresponding shared artifact.
4. **Shared-package churn.** A package consumed by several repos whose consumers
   change every time it does. Detector: co-change between the package and its
   consumers, which means the interface is leaking rather than absorbing change.

Apply the **deletion test** across the repo boundary: would deleting one copy, or
moving this module to the other side of the seam, concentrate complexity or just
relocate it? Concentration is the signal.

### 4. Report on two axes

Write a self-contained HTML file to the OS temp directory so nothing lands in any
repo. Resolve it from `$TMPDIR`, falling back to `/tmp` (`%TEMP%` on Windows), as
`<tmpdir>/workspace-architecture-<timestamp>.html`, open it (`open` on macOS,
`xdg-open` on Linux, `start` on Windows) and print the absolute path.

Use Tailwind and Mermaid from CDN. Mermaid earns its place here more than in a
single-repo report: the candidates are graph-shaped by nature, so draw the repos as
nodes and the friction as edges, before and after.

Every candidate is scored on **two axes, reported side by side and never merged into
one ranked list**:

- **Locality**: how much of the fix lands inside a single repo.
- **Choreography**: how much coordination the fix needs. How many repos change, in
  what order, across how many review queues, and whether a deploy order is implied.

A candidate can score well on one and badly on the other, which is the whole reason
they stay separate. Extracting a shared core inside one repo is high Locality; making
the other repo consume it is pure Choreography, and a single blended "Strong"
badge hides exactly the half that makes cross-repo work go wrong. Close with the
worst item **per axis** and refuse to name one overall winner.

Per candidate card: the repos and files involved, the class from step 3, the friction,
the proposed seam in `codebase-design` vocabulary, a before/after diagram, the two
axis scores, and any doc-versus-code contradiction found along the way.

Do not propose interfaces yet. Ask which candidate the user wants to explore.

### 5. Grilling loop

Call the Skill tool with "grilling" to walk the chosen candidate: which repo owns the
seam afterwards, what crosses it, what the migration order is, which tests move.

Side effects inline. Call the Skill tool with "domain-modeling" to keep the model
current:

- **A seam named after a concept missing from the workspace `CONTEXT.md`?** Add it
  there, not to a member repo's: a term that spans repos belongs to the set.
- **A candidate rejected for a load-bearing reason?** Offer an ADR in the
  **workspace** `docs/adr/`, created lazily. A cross-repo decision belongs to no
  single repo, and filing it in one hides it from the others.
- **A doc-versus-code contradiction confirmed?** That is a documentation fix in its
  own right. Offer it separately from the candidate, since it is worth landing even
  if the refactor never happens.
