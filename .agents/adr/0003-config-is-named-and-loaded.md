# Config is named and loaded, never assumed present

**Status: implemented for the naming rule.** `to-tickets`, `to-spec`, `triage`, `wayfinder`,
`domain-modeling`, `tdd`, `diagnosing-bugs` and `improve-codebase-architecture` name the config
file they read, alongside `two-axis-review`, which already did. The shelving described under "What happened to the
workspaces" is decided but not carried out: those skills still sit in `skills/engineering/`.

**This ADR replaces an earlier 0003, "Resolve the commons once at setup, not on every run."**
That decision was about which copy of a doc a skill reads when a workspace sits above the repo.
The workspace feature it decided about is being shelved (see below), so its subject is gone, but
its two central arguments were never about workspaces at all. They are restated here as the
general rule, and the workspace history is recorded rather than erased.

## The rule

A skill that depends on per-repo configuration **names the file it reads**. It does not say the
configuration was provided without naming it, does not probe the filesystem for it, and does not
infer its absence from having looked. Saying the config "should have been provided to you" is fine
and stays; the path that has to follow it is the whole point.

`/setup-skills` writes that configuration and records a summary plus a pointer in the
`## Agent skills` block of the repo's `CLAUDE.md`. **The block is the distribution mechanism**,
because it is the thing every session loads. A file under `docs/agents/` that no skill is told
to read is invisible, whatever it contains.

**Negatives are recorded too.** A block silent on some question is indistinguishable from a repo
where `/setup-skills` never ran, and "looked, found nothing, therefore nothing exists" is exactly
the inference a recorded answer exists to prevent. Recording the negative is what makes it a
resolution rather than an absence.

## Why

Three arguments, in order of weight. The first two are carried over from the superseded 0003 and
are stated in their general form.

- **A search that finds nothing establishes only that the search found nothing.** A probe that
  scans and returns "not present" is indistinguishable from the truth and is believed. A named
  file that is missing is a concrete, reportable condition: the skill says so and tells the user
  to run `/setup-skills`.
- **Ambiguity is a question for a person, and should be asked once**, at the moment the answer is
  being decided, not re-derived on every invocation of every skill.
- **A written file that nothing reads is a defect with no symptom.** This was found in the wild:
  one repo ran `/setup-skills`, which wrote a carefully customised `docs/agents/domain.md` and
  `docs/agents/triage-labels.md`, and `grep -rn` over `skills/` shows nothing reads either one
  except `setup-skills`, which writes them. The repo's own conventions sat in a file no skill was
  told to open. `two-axis-review` is the only skill that names its config file, and it is the
  only one that reliably gets it.

## What this costs

A named path is a coupling: rename `docs/agents/issue-tracker.md` and every skill naming it must
change. That is the correct trade. A probe survives the rename by finding nothing and reporting
success, which is worse than a break.

A declared pointer can go stale where a probe cannot. `/setup-skills` is re-runnable, and the
staleness is visible: a named file that is absent produces an error, not a silent default.

## What happened to the workspaces

The superseded 0003 argued this same rule for a **Commons**: the repo or workspace holding docs
shared across a set of repos. The workspace feature underneath it (`workspaces`, `new-workspace`,
`improve-workspace-architecture`, `sync-repos.sh`, `find-workspace.sh`) goes to `misc/`,
shelved before any workspace has ever existed: roughly two thousand lines of skill and
script, a probe paragraph injected into five skills, and eight tickets to remove that
paragraph again, serving zero instances. That is Speculative Generality, which
`two-axis-review`'s own smell baseline prescribes deleting until a real need shows.

The decision to shelve is independent of whether the superseded 0003 was right. It was right, and
what it was right about generalises past the feature that occasioned it, which is why this file
keeps the argument and drops the subject. If a workspace is ever created, those skills come back
out of `misc/` and this rule already covers how they record what they resolve.

## The gap in ADR 0001

ADR 0001 splits skills into hard and soft dependencies on per-repo config. The split has no
category for **hard only under a condition that is false in most repos**. Naming the file
collapses that conditional rather than picking a side of it: a skill names what it needs, and a
repo that has not been set up gets one honest error instead of a silent default.
