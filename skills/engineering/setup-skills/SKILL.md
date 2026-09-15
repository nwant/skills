---
name: setup-skills
description: "Configure this repo for the engineering skills: resolve the commons it belongs to, and set up its issue tracker, triage label vocabulary, and domain doc layout. Run once before first use of the other engineering skills."
disable-model-invocation: true
---

# Setup Skills

Scaffold the per-repo configuration that the engineering skills assume:

- **Commons**: which repo or workspace holds the docs that are shared with anything above this repo, resolved here once so no other skill has to work it out at run time
- **Issue tracker**: where issues live (GitHub by default; local markdown is also supported out of the box)
- **Triage labels**: the strings used for the five canonical triage roles
- **Domain docs**: where `CONTEXT.md` and ADRs live, and the consumer rules for reading them

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- **Which commons does this repo belong to?** Run the verifier once, here, and hold on to what it says. This is the only run there is: no other skill probes for the commons, they read what you record in step 4.

  Run the script directly rather than calling the Skill tool with `workspaces`. That is the one deliberate exception to reaching for another skill's material by invoking it: `workspaces` is the vocabulary layer and holds no resolution step of its own, and loading a whole skill to reach one asset would put back the per-run cost this design exists to remove. The script is a **verifier**, run once here, not a probe any skill runs.

  ```bash
  for d in ~/.claude/skills/workspaces/assets "${CODEX_HOME:-$HOME/.codex}/skills/workspaces/assets" \
           ~/.agents/skills/workspaces/assets .claude/skills/workspaces/assets; do
    [ -d "$d" ] && FW="$d/find-workspace.sh" && break
  done
  echo "verifier: ${FW:-MISSING}"
  command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 \
    && echo "prereqs: ok" || echo "prereqs: INCOMPLETE"
  [ -n "${FW:-}" ] && { bash "$FW"; echo "exit=$?"; }
  ```

  | Exit | What it printed | The commons |
  | --- | --- | --- |
  | 0 | one workspace path | that workspace |
  | 1, with `prereqs: ok` | nothing | none: this repo is standalone |
  | 2 | every claimant, one path per line | not yet decided, ask (step 2) |
  | 1, with `prereqs: INCOMPLETE` | nothing | **not established**: ask, see below |
  | `verifier: MISSING` | no exit line at all | **not established**: ask, see below |

  **Exit 1 has two meanings, and only one of them is an answer.** The verifier also exits 1 when it could not check, which is what the `prereqs` line separates. With `prereqs: ok`, exit 1 means *no commons above this repo*, which is the true answer for almost every repo, and step 4 records it in as many words.

  A repo with **no `origin` remote** is on the answer side of that line, not the unestablished side. Membership keys on the origin slug, so a repo without one cannot appear in any manifest, and a repo standing inside a workspace resolves at the walk-up step, which needs neither git nor a remote. A local-only repo is a first-class case here; do not ask it a question its own shape already answers.

  **Never record "standalone" off an unestablished answer.** On `prereqs: INCOMPLETE` or `verifier: MISSING`, say which piece is missing and ask the user whether a workspace claims this repo, rather than improvising a substitute for the verifier or treating silence as a no. A wrong answer here is durable in a way the old filesystem probe never was: the probe re-guessed on every run, whereas this gets written down once and believed by every session afterwards. A machine without `jq` would otherwise leave a repo permanently denying the workspace it really belongs to.

  A workspace's **name** is the basename of the directory the verifier printed (`~/github/payments-workspace` is `payments-workspace`); `repos.json` carries no name of its own. Carry the name forward, never the path: paths are machine-specific, and what you write has to stay true in every clone.

  **When a workspace is the commons, the config goes there**, not here: the tracker, its labels and the doc layout are identical for every member, so a copy per repo is N places to update and N chances to drift. Write `docs/agents/` into the workspace and put the `## Agent skills` block in the *workspace's* `CLAUDE.md`. Those three are then settled once per **workspace** rather than once per repo. The `### Commons` entry is the one part that stays per repo, because it is what a session standing in a member repo reads to find the workspace at all; step 4 writes it. Say in your closing summary which workspace you wrote to, and that every other member repo needs its own `### Commons` entry before a session there can find the workspace.
- `git remote -v` and `.git/config`: is this a GitHub repo? Which one?
- `AGENTS.md` and `CLAUDE.md` at the repo root: does either exist? Is there already an `## Agent skills` section in either?
- `CONTEXT.md` and `CONTEXT-MAP.md` at the repo root
- `docs/adr/` and any `src/*/docs/adr/` directories
- `docs/agents/`: does this skill's prior output already exist?
- `.scratch/`: a sign that a local-markdown issue tracker convention is already in use
- Is the `triage` skill installed? (a `triage` skill folder alongside this one, or `triage` in your available skills.) This decides whether Section B runs at all.
- Monorepo signals: a `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or a populated `packages/*` with its own `src/`. These are present only in a genuinely large multi-package repo; their absence means single-context, which is almost every repo.

### 2. Present findings and ask

Summarise what's present and what's missing, the resolved commons included. Then take the sections in order. One section, one answer, then the next.

**Settle the commons before the sections.** If the verifier exited 2, name the claimants and ask which one is this repo's commons, before anything else is asked or written: this step creates committed files, and putting them in the wrong workspace hides them from the one that needed them. **Never pick a claimant.** Several workspaces claiming one repo is normal rather than a misconfiguration, and only the user knows which one this repo's work belongs to. On exit 0 or 1 there is nothing to ask: state the answer in the summary and go on to Section A.

Lead each section with the recommended answer so the user can accept it in a word. Give a one-line explainer only when the choice genuinely branches; skip the section entirely when exploration already settled it (Section B when `triage` isn't installed, Section C when there's no monorepo).

**Section A: Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `to-tickets`, `triage`, and `to-spec` read from and write to it. They need to know whether to call `gh issue create`, write a markdown file under `.scratch/`, or follow some other workflow you describe. Pick the place you actually track work for this repo.

Default posture: these skills were designed for GitHub. If a `git remote` points at GitHub, propose that. If a `git remote` points at GitLab (`gitlab.com` or a self-hosted host), propose GitLab. Otherwise (or if the user prefers), offer:

- **GitHub**: issues live in the repo's GitHub Issues (uses the `gh` CLI)
- **GitLab**: issues live in the repo's GitLab Issues (uses the [`glab`](https://gitlab.com/gitlab-org/cli) CLI)
- **Shortcut**: issues live as Shortcut stories (uses the `mcp__shortcut__*` MCP tools)
- **Local markdown**: issues live as files under `.scratch/<feature>/` in this repo (good for solo projects or repos without a remote)
- **Other** (Jira, Linear, etc.): ask the user to describe the workflow in one paragraph; the skill will record it as freeform prose

**The remote host settles where the code lives, not where the work is tracked.** A GitHub Enterprise remote is the common case: the repo is on GitHub while stories live in Shortcut or Jira, and Issues is switched off. Read the remote as a proposal to confirm, and when a Shortcut MCP server is connected treat that as the stronger signal. Ask rather than assume whenever both are present.

Record the choice in `docs/agents/issue-tracker.md`. The GitHub and GitLab templates carry a "PRs as a request surface" flag, defaulted **off**. Leave it off and don't raise it: a user who wants external PRs in the triage queue can flip the flag in the file later. The Shortcut template pins the flag off permanently, since Shortcut holds no PRs.

**Section B: Triage label vocabulary.** Skip this section entirely if the `triage` skill isn't installed (exploration told you), since an uninstalled skill needs no labels.

Skip it for **Shortcut** too, and say so in a line: that tracker carries triage state as workflow state, and its template's "Triage roles" table is already the mapping. Write `triage-labels.md` from that table. A tracker whose labels are workspace-wide makes minting five new ones a change to every team's vocabulary, which is why the mapping reuses states the team already runs.

Otherwise, ask exactly one question:

> Do you want to keep the default triage labels? (recommended: **yes**)

The defaults are the five canonical roles, each label string equal to its name: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. On **yes**, write them as-is. Only if the user says no, usually because their tracker already uses other names (e.g. `bug:triage` for `needs-triage`), collect the overrides so `triage` applies existing labels instead of creating duplicates.

**Section C: Domain docs.** Default to **single-context** (one `CONTEXT.md` + `docs/adr/` at the repo root). This fits almost every repo; write it without asking.

Offer **multi-context** (a root `CONTEXT-MAP.md` pointing to per-context `CONTEXT.md` files) only when exploration found monorepo signals. Then confirm which layout they want.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` block to add to whichever of `CLAUDE.md` / `AGENTS.md` is being edited (see step 4 for selection rules), the `### Commons` entry included
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md` (the last only when `triage` is installed)

Let them edit before writing.

### 4. Write

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, ask the user which one to create; don't pick for them.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa); always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

The block:

```markdown
## Agent skills

### Commons

[one of the three wordings in the table below, verbatim]

### Issue tracker

[one-line summary of where issues are tracked]. See `docs/agents/issue-tracker.md`.

### Triage labels

[one-line summary of the label vocabulary]. See `docs/agents/triage-labels.md`.

### Domain docs

[one-line summary of layout: "single-context" or "multi-context"]. See `docs/agents/domain.md`.
```

Include the `### Triage labels` sub-block, and write `docs/agents/triage-labels.md`, only when `triage` is installed and Section B ran. When it isn't, both are omitted.

**Write the `### Commons` entry every time, including when there is no commons.** A block that says nothing about the commons is indistinguishable from a repo where this skill never ran, and "scanned, found nothing, therefore nothing exists" is the exact inference the recorded answer exists to prevent. Recording the negative answer is what makes it a resolution rather than an absence. One shape, three fillings. **Use the wording in the right-hand column verbatim**, so that a skill reading the entry, and `new-workspace` writing the same entry from the other end, are looking at one format rather than four paraphrases of one:

| Verifier | The entry reads |
| --- | --- |
| exit 0 | ``The `<name>` workspace above this repo. Its `CONTEXT.md`, ADRs and `docs/agents/` are the shared copies; this repo's own carry what is intrinsic to it. The rest of this block is in that workspace's `CLAUDE.md`. It can live anywhere on this machine, so ask the operator where it is rather than looking for it.`` |
| exit 1 | ``Standalone: no commons above this repo. Every doc a skill reads or writes here is this repo's own. See `docs/agents/domain.md`.`` |
| exit 2 | the exit-0 wording for the claimant the user picked, then ``Also claimed by `<the others>`; this one was chosen at setup.`` |

The pointer at the end differs because the layout detail follows the config: on exit 1 it is in this repo's `docs/agents/domain.md`, and on exit 0 or 2 it is in the workspace's, reached through the workspace's own block. Never point a member repo at a `docs/agents/domain.md` it does not have. Match whatever link style the block already uses: a backticked path where the other entries are backticked, a markdown link where they are links. The wording is what has to be verbatim, not the markup around the path.

**Name workspaces, never paths.** A name stays true in every clone on every machine; a path is true on one. Machine-specific paths belong in the workspace's `repos.local.json`, which is gitignored and already wins by name.

The closing clause about asking is not filler. A member repo holds no `docs/agents/domain.md` of its own, since that went to the workspace, so the entry is the *only* thing a session standing there has to go on. A name with no way to reach it is a name the reader will guess a path for, and guessing is what this whole mechanism exists to end. Asking is the right instruction rather than naming a location because **a member repo lives wherever its manifest entry says**, so there is no location the entry could name that would be true everywhere: adjacency proves nothing, which is exactly why the verifier keys on the manifest and not on what sits next to what.

`### Commons` and `### Domain docs` answer different questions and must not be made to overlap: `### Commons` says which repo or workspace is the authority above this one, `### Domain docs` says how the docs are laid out inside the place that authority points at. In a **member repo** the block carries `### Commons` alone, because the other three entries were written into the workspace's own block.

Then write the docs files using the seed templates in this skill folder as a starting point:

- [issue-tracker-github.md](./issue-tracker-github.md): GitHub issue tracker
- [issue-tracker-gitlab.md](./issue-tracker-gitlab.md): GitLab issue tracker
- [issue-tracker-shortcut.md](./issue-tracker-shortcut.md): Shortcut issue tracker
- [issue-tracker-local.md](./issue-tracker-local.md): local-markdown issue tracker
- [triage-labels.md](./triage-labels.md): label mapping (only if `triage` is installed)
- [domain.md](./domain.md): domain doc consumer rules + layout

For "other" issue trackers, write `docs/agents/issue-tracker.md` from scratch using the user's description.

### 5. Done

Tell the user the setup is complete and which engineering skills will now read from these files, and name the commons you recorded. Mention they can edit `docs/agents/*.md` directly later; re-running this skill is only necessary if they want to switch issue trackers, restart from scratch, or the commons has changed (this repo joined a workspace, or left one).
