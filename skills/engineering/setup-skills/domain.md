# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## The commons

The **commons** is the shared home an artifact routes to when it is meaningful to more than one unit of work. `CLAUDE.md`'s `### Commons` entry names it; this section is the layout that sits behind the name. It was resolved once, at `/setup-skills` time, and recorded. **No skill probes the filesystem for it.**

| Commons | What it means | Where the shared copies live | Recorded by |
| --- | --- | --- | --- |
| **Standalone** (almost every repo) | nothing above this repo | here: `CONTEXT.md`, `docs/adr/`, `docs/agents/` | `### Commons` |
| **A workspace** | a coordination directory holding what belongs to a set of repos rather than to any one of them | the workspace's `CONTEXT.md`, `docs/adr/`, `docs/agents/` | `### Commons` |
| **The repo root** (multi-context) | one repo, several contexts under `src/`, each with its own `CONTEXT.md` | the root `CONTEXT-MAP.md` and the root `docs/adr/` | `### Domain docs` |

The third row is in this table because it is a commons in the same sense as the other two: a copy shared by more than one unit of work. It is not something `### Commons` records, though, because that entry answers only what sits **above** this repo, and a multi-context layout sits inside it. That is `### Domain docs`' question, and the two entries stay out of each other's way.

Standalone is an answer, not a gap. A block that says nothing about the commons means setup never ran here; a block that says "standalone" means the question was asked and the answer was no.

**From the name to the directory.** The entry names a workspace and never a path, so it stays true in every clone on every machine. Look for it beside this repo, at `../<name>` from the repo root, which is the sibling layout `new-workspace` builds. If it is not there, say so and carry on without it. Do not scan for a replacement: a pointer that is wrong names a directory that does not exist, which is a visible failure, while a scan that finds nothing returns "no commons", which is indistinguishable from the truth and gets believed.

**When the commons is a workspace**, material that spans repos belongs to the workspace and material intrinsic to this repo belongs here. Read both glossaries and prefer this repo's on a conflict, being closer to the code. Write to exactly one: a term written to both drifts, and a term written into one member is invisible to the others.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root, or
- **`CONTEXT-MAP.md`** at the repo root if it exists: it points at one `CONTEXT.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in. In multi-context repos, also check `src/<context>/docs/adr/` for context-scoped decisions.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo (most repos):

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

Multi-context repo (presence of `CONTEXT-MAP.md` at the root):

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← context-specific decisions
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
