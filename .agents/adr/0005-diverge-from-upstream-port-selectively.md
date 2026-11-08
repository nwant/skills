# Diverge from upstream; port its changes selectively, never merge

This repo started as a fork of [mattpocock/skills](https://github.com/mattpocock/skills), and
the `upstream` remote still points there. Anyone who sees that remote will expect a periodic
`git merge upstream/main`. We don't do that, and won't.

## Why not merge

By the first review of upstream (2026-11-01, 94 upstream commits since the fork point), the
two trees had already parted in ways a merge cannot reconcile without re-fighting every
decision:

- **Renames upstream never made**: `ask-matt` to `which-skill`, `setup-matt-pocock-skills` to
  `setup-skills`, `code-review` to `two-axis-review`. Every upstream edit to those skills
  lands as a conflict or, worse, as a resurrected file under the old name.
- **Machinery we removed**: the Claude Code plugin, changesets and version bumps
  ([ADR 0002](./0002-ship-as-a-claude-code-plugin.md) records why). Upstream keeps adding
  changesets, and a merge brings them back.
- **Conventions upstream changed and we kept**: upstream renamed the glossary convention
  `CONTEXT.md` to `GLOSSARY.md`; this fork, the repos it has set up, and `docs/agents/domain.md`
  all use `CONTEXT.md`.
- **Different bucket judgments**: upstream graduated `pr`, `retro` and `implement-spec` and
  deleted `resolving-merge-conflicts`. Promotion here follows this repo's own use.

Tracking upstream would cost a conflict-heavy merge every time and buy nothing, because each
merge would still need the same hand review that a port does.

## Decision

Upstream is a **source of ideas**, not a parent. Each review reads upstream's changes since the
last-reviewed commit and ports, by hand, the ones worth having: rewritten onto our skill
names, our `CONTEXT.md` convention, our tracker-config rules
([ADR 0003](./0003-config-is-named-and-loaded.md)), and the no-em-dash rule. Release machinery,
repo-ops files (`SCOPE.md`, issue forms, triage workflows) and upstream's bucket moves are
skipped by default.

## Consequence: the merge-base never moves

Because nothing is ever merged, `git merge-base main upstream/main` stays at the fork point for
good, and a review based on it would show every upstream commit ever made. The last-reviewed
upstream commit is therefore recorded by hand in [`.agents/upstream.md`](../upstream.md), which
says how to review from it. This ADR holds the reasoning; that file holds the moving sha.
