---
name: two-axis-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side, never reranked into one verdict. Use when a diff should be checked against the issue or spec it came from as well as the repo's conventions, or when the user asks to \"review since X\"."
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

The issue tracker should have been provided to you. If `docs/agents/issue-tracker.md` is missing, tell the user to run `/setup-skills`. **First check one level up**: call the Skill tool with "workspaces" and run its probe, because in a workspace the config is written once into the workspace rather than into each member repo, and a missing file here usually means it is there. If more than one workspace claims the repo, **ask which one**: a tracker config is an authority, not a palette, and guessing points the Spec axis at the wrong set of stories.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in `docs/agents/issue-tracker.md`.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`. **In a workspace, add the workspace's own standards**: cross-cutting rules (alerting, config, shared contracts) are recorded once above the repos, so a Standards axis that reads only this repo misses the half that spans them. Where the two conflict, the repo wins, since it is closer to the code. **Never union two workspaces' standards**: if more than one claims the repo, ask which programme this diff belongs to, because judging a change against rules its programme does not follow is worse than judging it against none.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- **Whether the spec is satisfied by more than this diff**, and if so, which repo each unmet requirement plausibly belongs to (see below).
- The brief: "Report: (a) requirements the spec asked for that this diff neither satisfies nor plausibly leaves to a sibling; (b) requirements that appear to belong to a **sibling** change elsewhere, named as such rather than as missing; (c) behaviour in the diff that wasn't asked for (scope creep); (d) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

#### One spec, several changes

A spec whose requirements are satisfied across **more than one repo** is the normal case
in a multi-repo workspace, not an exception. Judging one diff against the whole spec then
reports the other repos' requirements as **missing**, when they are merely **elsewhere**,
and it does so on most of the work rather than rarely.

So before the Spec axis reports anything absent, decide which of three dispositions each
unmet requirement has:

- **Not delivered.** Nothing anywhere satisfies it. A real finding.
- **Sibling-owned.** It plausibly belongs to a change in another repo, on the evidence of
  the spec's own wording and the surfaces it names. Report it as that, naming the repo,
  never as missing.
- **Out of scope.** The spec asks for something this change was never meant to cover.

**Classifying is required; searching is optional.** The spec text and the repos it names
are usually enough to say "this belongs to the API side". Where it is cheap, confirm by
looking for the sibling change (a shared ticket id in a branch or title across the
workspace's repos is the reliable handle) and say whether you found one. Reading three
diffs to review one triples the context and blunts the review, so do not do it by
default, and never let an unfound sibling promote a requirement back to *missing*: absence
of a search result is not evidence.

If a workspace is in effect, call the Skill tool with "workspaces" for how to resolve it
and for the **sibling PR** vocabulary. Outside a workspace this whole section collapses:
one repo, one diff, and the three dispositions reduce to the two the axis always had.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

Report a **sibling-owned** requirement under the Spec axis as its own line, not folded in with the missing ones: the reader's next action differs completely, chase another repo versus write code here.

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
