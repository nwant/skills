# The canonical install block

One install story, one wording. `README.md` and every bucket `README.md` must say **this** and nothing else. Change it here first, then propagate.

This repo is a fork of [mattpocock/skills](https://github.com/mattpocock/skills). Upstream ships a Claude Code plugin; **this fork does not**. There is no plugin manifest, no marketplace entry, and no release, so every `claude plugins install` and `/plugin install` form belongs to upstream and installs upstream's skills, not these. See [adr/0002-ship-as-a-claude-code-plugin.md](./adr/0002-ship-as-a-claude-code-plugin.md).

## The only route

<canonical-block name="link-skills">

```bash
git clone https://github.com/nwant/skills.git
cd skills
./scripts/link-skills.sh
```

Symlinks every skill outside `deprecated/` and `misc/` into the directory each harness reads: `~/.claude/skills` (Claude Code), `$CODEX_HOME/skills`, default `~/.codex/skills` (Codex), and `~/.agents/skills` (other Agent Skills-compatible harnesses). Codex reads `$CODEX_HOME/skills` and not `~/.agents/skills`, so both are linked; Codex's bundled skills sit in a `.system` subdirectory there and are left alone.

The skills are files you own and edit: a change is live in the next session, and `git pull` updates every installed skill at once. Re-run the script after adding, removing, or renaming a skill, and restart any session that was already open.

</canonical-block>

## Why only one

A plugin installs a managed, read-only bundle you subscribe to. That is the wrong shape for a repo you forked in order to change: it would hand you a copy you cannot edit, and it would cost a manifest entry, a changeset, and a version bump on every new skill. Symlinking the working tree gives the editable copy and the update path in one step, with no release process behind it.

This also means there is nothing to publish. Skills reach another machine by cloning the repo there.

## Not the install story

**skills.sh.** Upstream documents `npx skills@latest add mattpocock/skills`. `https://skills.sh/nwant/skills` returns 404 and the CLI's resolution rule (arbitrary GitHub repo, or registry-listed only?) is undocumented, so **no skills.sh command is published for this fork**. Verify the command actually resolves before adding one.
