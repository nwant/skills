# Resolve the commons once at setup, not on every run

**Status: decided, not yet implemented.** `find-workspace.sh` still scans, `new-workspace`
still defines members by adjacency, and nothing writes or reads a commons pointer.
Changing that means edits to `new-workspace`, `workspaces`, `find-workspace.sh`,
`sync-repos.sh`, `setup-skills`, and the workspace paragraphs in `domain-modeling`,
`two-axis-review`, `to-spec`, `which-skill` and `wait-what`.

Skills that read or write a domain doc have to answer one question: **which copy?**
The repo's `CONTEXT.md` or the one above it, this repo's `docs/adr/` or the shared
one, the tracker config here or the one written once for a set of repos. We call the
answer the **Commons**.

The collection answered that question twice, in two incompatible ways. A multi-context
repo declares it: `CONTEXT-MAP.md` exists, `docs/agents/domain.md` describes the
layout, and skills read a file. A **Workspace** probed for it: `find-workspace.sh`
scanned the filesystem at runtime, and five skills carried a paragraph telling them to
call the probe.

**We resolve the commons once, at `/setup-skills` time, and record it where the
existing config already reaches skills:** a line in the `## Agent skills` block of the
repo's `CLAUDE.md`, naming the commons, with the layout detail in
`docs/agents/domain.md` beside it. No skill probes.

The block is the distribution mechanism, not `domain.md`. Nothing reads `domain.md` on
its own; `setup-skills` writes it and writes a one-line summary plus a pointer to it
into `CLAUDE.md`, which every session loads. A commons recorded only in `domain.md`
would be as invisible as one that was never recorded.

Three reasons, in order of weight:

- **Membership cannot be inferred from the filesystem.** A **Member repo** lives
  wherever its manifest entry says, so there is no bounded directory to scan. A probe
  that scans and finds nothing returns *"no workspace"*, which is indistinguishable
  from the truth and is believed. A declared pointer that is wrong names a path that
  does not exist.
- **Ambiguity is a question for a person, and should be asked once.** A repo may
  belong to several workspaces. Probing re-asks that on every invocation of every
  skill; resolving at setup asks it when the answer is being decided.
- **Most repos have no commons above them, and paid for the check anyway.** The probe
  cost context on every run of `domain-modeling`, `two-axis-review`, `to-spec`,
  `which-skill` and `setup-skills`, in every single-repo project, to establish
  something that was false and stayed false.

## What this costs

`new-workspace` writes a pointer **down** into each member's `docs/agents/`, naming
its workspaces by name. That reverses the skill's own rule that repo-intrinsic facts
are never duplicated upward and members are never written into. The rule stands for
*content*: a member's `CLAUDE.md` is still its own. Membership is not content, it is
an address, and an address the repo cannot derive has to be told to it.

The pointer names workspaces, never paths, so it stays true in every clone on every
machine. Paths are machine-specific and belong in `repos.local.json`, which is already
gitignored, already merged last, and already wins by name.

A declared pointer can go stale where a probe cannot. `find-workspace.sh` survives as
the **verifier** `/setup-skills` runs, not as something every skill runs.

## The gap in ADR 0001

ADR 0001 splits skills into hard and soft dependencies on per-repo config. The
workspace paragraphs were argued in as a hard dependency, and for `domain-modeling`
that is defensible: writing a cross-repo term into one member hides it from the
others. But the split has no category for **hard only under a condition that is false
in most repos**, and that is the real shape. Resolving at setup collapses the
conditional rather than picking a side of it.
