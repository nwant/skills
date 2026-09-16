# nwant Skills

A collection of agent skills (slash commands and behaviors) loaded by Claude Code. Skills are organized into buckets and consumed by per-repo configuration emitted by `/setup-skills`.

## Language

### Tracking work

**Issue tracker**:
The tool that hosts a repo's issues: GitHub Issues, Linear, a local `.scratch/` markdown convention, or similar. Skills like `to-tickets`, `to-spec`, and `triage` read from and write to it.
_Avoid_: backlog manager, backlog backend, issue host

**Issue**:
A single tracked unit of work inside an **Issue tracker**: a bug, task, spec, or slice produced by `to-tickets`.
_Avoid_: ticket (use only when quoting external systems that call them tickets, or for a **Decision ticket**, see below)

**Decision ticket**:
A `wayfinder` unit: a child **Issue** of a `wayfinder:map` holding a *question* whose resolution is a decision, not a slice of a build to execute. The **decision** qualifier is what keeps it distinct from an implementation ticket; `wayfinder` introduces the term, then uses "ticket".

**Triage role**:
A canonical state-machine label applied to an **Issue** during triage (e.g. `needs-triage`, `ready-for-afk`). Each role maps to a real label string in the **Issue tracker** via `docs/agents/triage-labels.md`.

### Multi-repo vocabulary

These terms belong to the three workspace skills, which are shelved in `skills/misc/` and not
installed. They stay here because those skills still use them and are still readable. No promoted
skill speaks this vocabulary. See [.agents/adr/0003-config-is-named-and-loaded.md](./.agents/adr/0003-config-is-named-and-loaded.md).

**Workspace**:
A coordination directory holding what belongs to a set of repos rather than to any one of them. It holds no repos itself, and its members may live anywhere on the filesystem.
_Avoid_: monorepo (one git root, the opposite shape), umbrella repo, project, "workspace" for a plain working directory

**Member repo**:
A repo a **Workspace** claims, with its own git history and its own `CLAUDE.md`. Membership is declared in the workspace manifest and is many-to-many: one repo belonging to several workspaces is normal.
_Avoid_: subrepo, submodule, package (all imply containment), sibling (implies a fixed location)

**Core repo** / **Adjacent repo**:
A **Member repo** the team owns and changes, versus one it reads from or is affected by but does not own. The manifest's `tier` is the authority.
_Avoid_: "the repos" used loosely, which is how three lists end up disagreeing

**Cross-repo unit of work**:
One **Issue** whose completion spans more than one **Member repo**, and so more than one pull request.
_Avoid_: multi-repo change (describes the diff, not the unit), epic (a tracker noun)

**Sibling PR**:
Another pull request implementing the same **Cross-repo unit of work**, in a different **Member repo**. The term earns its place by fixing a bug class: a review that judges one PR against the whole unit reports the siblings' requirements as *missing* when they are merely *elsewhere*.
_Avoid_: related PR (too weak), stacked PR (a dependent branch)

## Relationships

- An **Issue tracker** holds many **Issues**
- An **Issue** carries one **Triage role** at a time
- A **Decision ticket** is an **Issue** (a child of a `wayfinder:map`)
- A **Workspace** claims many **Member repos**; a **Member repo** may belong to several **Workspaces**
- A **Member repo** is either a **Core repo** or an **Adjacent repo**
- A **Cross-repo unit of work** is an **Issue** satisfied by several **Sibling PRs**

## Flagged ambiguities

- "backlog" was previously used to mean both the *tool* hosting issues and the *body of work* inside it. Resolved: the tool is the **Issue tracker**; "backlog" is no longer used as a domain term.
- "backlog backend" / "backlog manager". Resolved: collapsed into **Issue tracker**.
- "workspace" meant five different things across shipped skills: the coordination directory (`workspaces`, `new-workspace`), a teaching directory (`teach`), the current working directory (`loop-me`, `handoff`), and a student subdirectory (`scaffold-exercises`). Resolved: **Workspace** is the coordination directory alone; the other uses are to say "directory", "working directory" or "exercise directory".
- **Member repo** was defined as a filesystem *sibling* of the workspace, and resolution scanned for adjacency. Resolved: membership is declared in the manifest; a member lives wherever its path says, and adjacency proves nothing.
