# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root.
- **`.agents/adr/`**: read ADRs that touch the area you're about to work in.

**This repo keeps its ADRs in `.agents/adr/`, not `docs/adr/`.** Several skills name `docs/adr/` in their own text (`domain-modeling`, `improve-codebase-architecture`, `workspaces`, `new-workspace`, `improve-workspace-architecture`, among others), because that is the default for every other repo. Here, read and write `.agents/adr/` instead, and don't create a `docs/adr/` directory. The reason is recorded in `CLAUDE.md`: `docs/` is the reader-facing tree, so an ADR there would land among the skill pages, while `.agents/` already holds the material about authoring this repo.

This is a **single-context** repo: one `CONTEXT.md` at the root, no `CONTEXT-MAP.md`, no per-context ADR directories.

**Say which of these you read and which were absent.** A reader cannot otherwise tell whether a term was missing from the glossary or the glossary was never opened, and an empty result is a claim rather than a finding. Don't suggest creating a missing file upfront: the `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

```
/
├── CLAUDE.md          ← AGENTS.md is a symlink to this file; edit CLAUDE.md by name
├── CONTEXT.md
├── .agents/
│   └── adr/
│       ├── 0001-explicit-setup-pointer-only-for-hard-dependencies.md
│       ├── 0002-ship-as-a-claude-code-plugin.md
│       ├── 0003-config-is-named-and-loaded.md
│       └── 0004-tracker-capabilities-live-in-tracker-config.md
├── docs/
│   ├── agents/        ← this directory: skill-facing config
│   ├── engineering/   ← human-facing skill pages
│   └── productivity/
└── skills/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0002 (ship as a Claude Code plugin), but worth reopening because…_
