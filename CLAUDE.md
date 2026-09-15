Skills are organized into bucket folders under `skills/`:

- `engineering/`: daily code work
- `productivity/`: daily non-code workflow tools
- `misc/`: kept around but rarely used, not promoted
- `in-progress/`: beta: public on purpose, feedback wanted, not promoted
- `deprecated/`: no longer used

Every skill in `engineering/` or `productivity/` (the **promoted** buckets) must have a reference in the top-level `README.md`. Skills in `misc/`, `in-progress/`, and `deprecated/` must not appear there.

There is one way in: `scripts/link-skills.sh`, worded once in [.agents/install-block.md](./.agents/install-block.md) and copied verbatim wherever install commands appear. The repo ships no plugin manifest, no package manifest, and no release process, so adding a skill needs no manifest entry and no version bump. Why that path was dropped, and the upstream reasoning it reverses, lives in [.agents/adr/0002-ship-as-a-claude-code-plugin.md](./.agents/adr/0002-ship-as-a-claude-code-plugin.md).

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`. The promoted buckets' `README.md`s and the top-level `README.md` group entries into **User-invoked** and **Model-invoked**; non-promoted bucket `README.md`s (`misc/`, `in-progress/`) use a flat list.

Skills in `engineering/` and `productivity/` also have a human-facing docs page at `docs/<bucket>/<skill-name>.md` (the docs tree mirrors those two bucket folders under `skills/`). Docs pages are read in the repo, so links between them are repo-relative (`./<name>.md` within a bucket, `../<bucket>/<name>.md` across buckets). When you add, rename, or change the behaviour of a skill in `engineering/` or `productivity/`, create or re-sync its docs page following [.agents/writing-docs.md](./.agents/writing-docs.md). A finished page carries four sections: **What it does**, **When to reach for it**, **Common questions**, and **It's working if**. `writing-docs.md` holds the template, the section order, and where to hunt for the questions. Skills in the non-promoted buckets (`misc/`, `in-progress/`, `deprecated/`) get **no** docs page.

Decisions about this repo live in [.agents/adr/](./.agents/adr/), not `docs/adr/`. The `docs/` tree above is reader-facing, so an ADR there lands among the skill pages; `.agents/` is already where material about authoring this repo sits. The `docs/adr/` default that `domain-modeling` ships still holds for every other repo.

Every `SKILL.md` is either user-invoked (`disable-model-invocation: true` plus `policy.allow_implicit_invocation: false` in `agents/openai.yaml`, reachable only by the human) or model-invoked (model- or user-reachable). See [.agents/invocation.md](./.agents/invocation.md).

[`which-skill`](./skills/engineering/which-skill/SKILL.md) is the router that maps every user-reachable skill and how they relate. The same trigger that re-syncs a docs page applies to it: whenever you add, rename, remove, or change how a user-reachable skill fits the flows, re-read `which-skill`'s `SKILL.md` and update it so the map stays accurate: a new skill it never mentions, or a stale one it still routes to, is a router that lies.

To (re)link every skill outside `deprecated/` and `misc/` into the local harness skill directories (`~/.claude/skills` for Claude Code, `$CODEX_HOME/skills` for Codex, `~/.agents/skills` for other Agent Skills-compatible harnesses), run `scripts/link-skills.sh`. Codex reads `$CODEX_HOME/skills` and not `~/.agents/skills`, so both are linked. Each entry is a symlink into this repo, so a `git pull` keeps installed skills current; re-run the script after adding, removing, or renaming a skill.

No em-dashes anywhere in this repo's prose (`SKILL.md` files, docs, `README.md`, `CHANGELOG.md`, ADRs, code comments). Where a sentence reaches for one, rewrite it instead with a comma, colon, period, parentheses, or a conjunction, whichever the sentence actually wants; never do a blind character substitution.

## Agent skills

### Commons

Standalone: no commons above this repo. Every doc a skill reads or writes here is this repo's own. See [docs/agents/domain.md](./docs/agents/domain.md).

### Issue tracker

Issues live as GitHub issues on `nwant/skills`, the `origin` remote, driven by the `gh` CLI with `--repo` pinned because this is a fork. See [docs/agents/issue-tracker.md](./docs/agents/issue-tracker.md).

### Triage labels

The five canonical roles, each label string equal to its name. See [docs/agents/triage-labels.md](./docs/agents/triage-labels.md).

### Domain docs

Single-context: `CONTEXT.md` at the root, ADRs in `.agents/adr/` rather than `docs/adr/`. See [docs/agents/domain.md](./docs/agents/domain.md).
