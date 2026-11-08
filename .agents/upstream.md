# Upstream review marker

This fork ports [mattpocock/skills](https://github.com/mattpocock/skills) changes by hand and
never merges them ([ADR 0005](./adr/0005-diverge-from-upstream-port-selectively.md)), so
`git merge-base` cannot tell you what has already been reviewed. This file can.

**Last reviewed upstream commit:** `4ae2317` (2026-10-31, "software-factory: glossary skill for
designing a factory").

## Reviewing again

```bash
git fetch upstream
git log --oneline 4ae2317..upstream/main
git diff --stat 4ae2317 upstream/main -- skills docs CLAUDE.md
```

Port what is worth having, mapping upstream names onto ours as you go:

| Upstream | Here |
| --- | --- |
| `ask-matt` | `which-skill` |
| `setup-matt-pocock-skills` | `setup-skills` |
| `code-review` | `two-axis-review` |
| `GLOSSARY.md`, `GLOSSARY-MAP.md` | `CONTEXT.md`, `CONTEXT-MAP.md` |
| `docs/adr/` (this repo only) | `.agents/adr/` |

Convert British spellings to American in everything you port (see the spelling rule in
[`CLAUDE.md`](../CLAUDE.md)); upstream writes British English (-our, -ise, doubled L, and the like).

Then update the sha above to the `upstream/main` commit you reviewed up to, in the same pull
request as the ports.

## Reviewed and deliberately not ported

As of `4ae2317`, so a later review doesn't reopen them without a reason:

- The `GLOSSARY.md` rename, and `setup-skills`' offer to migrate a legacy `CONTEXT.md`.
- Changesets, version bumps, the plugin-first README, `.github` issue forms and triage
  workflows, `SCOPE.md`.
- The graduation of `pr`, `retro` and `implement-spec` to `engineering/` (their content was
  ported into `in-progress/`), and the deletion of `resolving-merge-conflicts`.
- `chief-of-staff` and `software-factory`.
- The docs-wide prose rewrite ("unslop every docs page").
