# setup-skills

## What it does

`setup-skills` answers four questions about one repo: which commons it belongs to, where issues live, what the triage labels are called, and where the domain docs sit. It records the answers as markdown files under `docs/agents/`, plus a short block in `CLAUDE.md` summarising each one.

Those files are the only thing that varies between repos. The skills themselves are identical everywhere; they read `docs/agents/issue-tracker.md` at run time and do what it says. That is why the set is not tied to GitHub, and why no skill file ever needs editing to point it somewhere else. Invoking it with "link the skills to a custom issue tracker" works with anything you can connect to programmatically, with zero changes to the skills.

It is a prompt-driven skill, not a deterministic script. It reads your `git remote`, your existing `CLAUDE.md`, your existing `CONTEXT.md`, proposes what it found, and waits for you to confirm before writing anything.

## When to reach for it

You invoke this by typing `/setup-skills`; the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) won't reach for it on its own. It is deliberately marked non-invokable, so no other skill can fire it for you.

Reach for it once per repo, before the first use of any other engineering skill. Where a workspace is the commons, reach for it once for the workspace, and once more in each member repo that still needs its pointer at it. If [triage](./triage.md), [to-spec](./to-spec.md), [to-tickets](./to-tickets.md) or [wayfinder](./wayfinder.md) start guessing where your issues go, or apply labels your tracker doesn't have, they have not been set up here yet. A repo already halfway through a project is a fine place to run it; the skill reads what is already there and no earlier work is wasted.

## Prerequisites

It writes into the repo you run it in:

| It writes | Where |
| --- | --- |
| `issue-tracker.md` | `docs/agents/` |
| `domain.md` | `docs/agents/` |
| `triage-labels.md` | `docs/agents/`, only when the `triage` skill is installed |
| An `## Agent skills` block | whichever of `CLAUDE.md` / `AGENTS.md` already exists |

All of it is committed markdown. There is no user-level or global mode: the config lives in the repo, so every repo gets its own copy.

Where a [workspace](./workspaces.md) is the commons, the three `docs/agents/` files and the block go into the *workspace* instead, and the repo you ran it in keeps one thing: a `### Commons` entry naming that workspace. Run it once per workspace in that case, and once in each member repo that still needs its pointer.

## The four answers

It leads each section with the recommended answer, and skips whatever exploration already settled. Most runs are two confirmations and done.

| Answer | What it proposes | When it actually asks |
| --- | --- | --- |
| **Commons** | whatever the verifier resolved, which for almost every repo is "standalone" | only when more than one workspace claims the repo, and then it never picks for you |
| **Issue tracker** | the one matching your `git remote` | always: this is the one real choice |
| **Triage labels** | keep the five canonical names (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) | only if the `triage` skill is installed |
| **Domain docs** | single-context: one `CONTEXT.md` plus `docs/adr/` at the root | only if it spots monorepo signals, and then it offers a multi-context `CONTEXT-MAP.md` |

The **commons** is the one of the four you do not answer. It is the shared home a doc routes to when it means something to more than this repo: a [workspace](./workspaces.md) above the repo, or nothing at all. Setup runs `find-workspace.sh` once, here, and writes down what it found, so that no skill ever has to work it out again at run time. Where a workspace is the commons, the tracker, labels and doc layout are written into *that* workspace rather than into each member, since they are identical for every member and N copies are N chances to drift.

The tracker options:

| Option | Where issues live | Needs |
| --- | --- | --- |
| **GitHub** | the repo's GitHub Issues | the `gh` CLI |
| **GitLab** | the repo's GitLab Issues | the `glab` CLI |
| **Shortcut** | Shortcut stories | a connected Shortcut MCP server |
| **Local markdown** | files under `.scratch/<feature>/` in this repo | nothing: no remote at all |
| **Other** | wherever you say | one paragraph from you describing the workflow |

The first four ship as templates in the skill and work out of the box. Local markdown is a first-class option, not a fallback: a solo project with no remote is fully supported. One caveat is worth repeating: don't use local markdown if you're using GitHub. They are alternatives, not layers.

Shortcut is the one template driven by MCP tools rather than a CLI, and the one where the remote is a red herring: the repo lives on GitHub (often GitHub Enterprise, with Issues switched off) while the work is tracked in Shortcut. Setup reads the remote as a proposal and asks rather than assuming whenever a Shortcut server is also connected.

"Other" is not a stub either. It is the reason Jira, Linear, Azure DevOps and Beads all work: you describe the workflow, the skill records your prose in `docs/agents/issue-tracker.md`, and the downstream skills follow the prose. The community has already done this: a Jira-over-[MCP](https://www.aihero.dev/ai-coding-dictionary/mcp) variant, a Gitea CLI shaped like `gh`, a hand-built local dashboard.

## Common questions

**Do I have to use GitHub?**

No. GitHub, GitLab, Shortcut and local markdown under `.scratch/` all ship as ready-made templates, and anything else works through the "other" path. This is the most-repeated question in the record, in roughly these words: *"hard locked to github"*, *"can I use GitLab / Jira"*, *"what about Azure DevOps"*. The answer every time is that the tracker is a setup answer, not a skill property.

**Do I need to re-run it after updating the skills?**

The direct answer is yes; the skill's own closing message is softer: it tells you re-running is only needed to switch trackers or start over. Both are defensible and the reason for the gap is real: the seed templates change between versions, so a `docs/agents/issue-tracker.md` written by an older release can go stale against the skills now reading it. If a downstream skill starts doing something the docs describe differently, re-running is the cheap fix.

**It wrote to `CLAUDE.md`, but I'm on Codex.**

Known gap, still open. The file-selection rule is "edit `CLAUDE.md` if it exists, else `AGENTS.md`": it checks which file exists, not which [harness](https://www.aihero.dev/ai-coding-dictionary/harness) is running. A repo with a `CLAUDE.md` left over from Claude Code will get its `## Agent skills` block somewhere Codex never reads. Two workarounds are in circulation: move the block to `AGENTS.md` by hand, or keep `AGENTS.md` canonical and make `CLAUDE.md` a one-line pointer at it. If neither file exists, the skill asks you which to create rather than picking, which has confused people who expected it to just decide.

**It didn't create my triage labels.**

It doesn't. `docs/agents/triage-labels.md` is a *mapping*: it tells `/triage` which strings in your tracker correspond to the five canonical roles. It does not run `gh label create`. On a fresh GitHub repo the labels genuinely do not exist yet, and this has been filed as a bug more than once. Two follow-ons:

- If your tracker already uses the canonical names, the mapping is an identity table and there is nothing to configure. That is the intended common case, not a missing step.
- [wayfinder](./wayfinder.md)'s `wayfinder:map` and `wayfinder:<type>` labels are not created here either, and `gh issue create --label <missing>` fails outright rather than creating the label. Create them by hand before the first wayfinder run on a GitHub repo.
- On **Shortcut** there is nothing to create and nothing to ask: triage state is workflow state, so the mapping points the five roles at states the team already runs, and the section is skipped. The same reasoning keeps wayfinder off labels there, recording a ticket's type in its description instead. Shortcut labels are workspace-wide, so minting one is a change to every team's vocabulary rather than a local setup step.

**Why does it write down that I have no workspace?**

Because a repo that says nothing about its commons is indistinguishable from one where setup never ran. "Standalone, no commons above this repo" is a recorded answer; silence is an unanswered question, and a skill meeting silence has to go looking. The old design did exactly that, scanning the filesystem on every run of five different skills, in every single-repo project, to establish something that was false and stayed false. Worse, a scan that finds nothing returns "no commons", which is indistinguishable from the truth and gets believed. Writing the negative answer down is what turns it into a resolution.

**Can I configure the other skills' behaviour here ([grilling](https://www.aihero.dev/ai-coding-dictionary/grilling) cadence, question format, tone)?**

No. It configures four things: the commons, the tracker, the labels, the doc layout. There have been direct requests to make it the home for per-user preferences, and the standing answer is that skills stay opinionated: *"Config is death."* Preferences belong in your `CLAUDE.md` as plain instructions, which every skill already reads.

**Can I keep the config in `~/.claude` instead of committing it to every repo?**

Not today. There is an open request for exactly this from someone running the skills across many repos, and no user-level mode exists. Every repo carries its own `docs/agents/`.

**Isn't it strange to have a skill that configures the other skills?**

One long-standing complaint says yes, in these words: *"having a skill to set up the other skill does not feel right to me: that means the LLM is configuring its own skills."* The trade is real and acknowledged: the alternative to a setup step is duplicating tracker instructions into every skill that touches issues. The output is inspectable, editable markdown, which is the mitigation: you can read every file it wrote and change it by hand, and day-to-day tweaks are exactly that, not another run.

## It's working if

- `docs/agents/issue-tracker.md` and `docs/agents/domain.md` exist, plus `triage-labels.md` if `triage` is installed.
- An `## Agent skills` section appears in the instruction file your harness actually reads, with a one-line summary pointing at each of those files.
- That section has a `### Commons` entry, and it says something either way. On almost every repo it reads "standalone, no commons above this repo", and an entry that is missing rather than negative is the tell that this run did not finish.
- Where it could not establish the answer, because `jq` or `git` is missing, or the verifier is not installed, it said so and asked. An entry reading "standalone" that it never had the means to check is the one failure worth watching for.
- The tracker it recorded is the one you really track work in, which is not always the one your remote implies, and the role mapping names labels or states that really exist there.
- Afterwards, `/to-tickets` publishes without asking you where issues live, and `/triage` applies labels rather than inventing them.
- Nothing in the skill files themselves changed. If setup edited a `SKILL.md`, something went wrong.

## Where it fits

`setup-skills` is the **run-once setup** for the engineering flow, the precondition everything else assumes rather than a step in the chain. Its neighbours are its readers: [triage](./triage.md), which applies the label vocabulary written here; [to-spec](./to-spec.md) and [to-tickets](./to-tickets.md), which publish into the tracker named here; and [wayfinder](./wayfinder.md), which reads the "Wayfinding operations" section of the same tracker file to know how maps and child [tickets](https://www.aihero.dev/ai-coding-dictionary/ticket) are stored. The domain-doc layout it records is the one [domain-modeling](./domain-modeling.md) fills in later: it creates `CONTEXT.md` and ADRs lazily, when a term or decision actually gets resolved, so an empty repo after setup is the expected state. For which skill to reach for next, [which-skill](./which-skill.md) routes the whole set.
