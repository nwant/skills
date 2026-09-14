# Issue tracker: Shortcut

Issues and specs for this repo live as Shortcut stories. Use the `mcp__shortcut__*`
MCP tools for all operations; Shortcut ships no CLI, so a connected MCP server is the
hard requirement.

Story ids are **numbers** in every tool call (`storyPublicId: 285340`), while prose,
branches, and commits write them `sc-285340`. Strip the prefix before calling.

## Identifiers to record at setup

`stories-create` requires either a `team` or a `workflow`, and moving a story needs a
numeric `workflow_state_id`. Discover these once with `teams-list` and
`workflows-list`, then write them into this section, because rediscovering them costs
a full listing of every team and workflow in the workspace on each run.

| What | Value |
| --- | --- |
| Team id | _fill in_ |
| Workflow id | _fill in_ |
| State for work that is ready to pick up | _fill in_ |
| State for work in progress | _fill in_ |
| State for work in review | _fill in_ |
| State for completed work | _fill in_ |
| State for work that will not be done | _fill in_ |

**Pass the team id, never the mention name.** Mention names get renamed, and a stale
one returns zero stories with no error, so an empty search result is a wrong-name
symptom before it is an answer.

## Conventions

- **Create a story**: `stories-create` with `name`, `description`, `team`, and `type`
  (`feature` / `bug` / `chore`). Leave `owner_ids` unset unless told who owns it:
  stories are normally claimed by whoever picks them up, so an owner you invent is a
  wrong claim on someone's queue.
- **Read a story**: `stories-get-by-id`. Add `stories-get-history` when how it reached
  its current state matters.
- **Find stories**: `stories-search` (`team`, `state`, `label`, `owner: "me"`,
  `isDone`, `isBlocked`, `hasOwner`, `epic`, `name` contains). It has **no** `parent`
  filter, so any set of stories you intend to query as a group belongs in an epic.
- **Comment**: `stories-create-comment`.
- **Move state**: `stories-update` with `workflow_state_id`.
- **Label**: `stories-update` with `labels: [{ name }]`. Shortcut labels are
  **workspace-wide** rather than per-team or per-repo, so reuse an existing one; a new
  label is a change to every team's vocabulary, not a local setup step.
- **Close**: `stories-update` to the completed state, or the will-not-be-done state.
- **Attach a PR**: `stories-add-external-link`. Read links back with care: they are a
  flat list per story, so a link on one story of a related pair does not establish
  which story the PR implements.
- **Branch name**: `stories-get-branch-name` gives the convention the workspace
  expects.

Descriptions cap at 10000 characters. Write them why-first, with testing steps a
reader can run: a spec that needs the authoring conversation to make sense has not
been published.

## Triage roles

Shortcut carries triage state as **workflow state**, not as labels, so the canonical
roles map onto the states recorded above. Every Shortcut state declares a `type`
(`backlog`, `unstarted`, `started`, `done`), which is what makes this mapping portable
across workspaces whose state *names* differ:

| Role | State |
| --- | --- |
| `needs-triage` | the `backlog` state |
| `ready-for-agent` | the ready-to-pick-up `unstarted` state |
| `ready-for-human` | the same state, plus an owner |
| `wontfix` | the `done` state meaning will-not-be-done |

`needs-info` has **no** state equivalent. Express it as a comment naming what is
missing, leaving the story where it is; it returns to `needs-triage` when the reporter
answers.

Prefer this mapping over creating the five canonical labels. Because labels are
workspace-wide, minting them edits the vocabulary of every team sharing the workspace,
to express state the workflow already models.

## Pull requests as a triage surface

**PRs as a request surface: no**, and this one is not a flag to flip: Shortcut holds
no PRs. A bare `#42` is a PR number on the code host, never a story id.

## When a skill says "publish to the issue tracker"

`stories-create` in the recorded workflow, in the ready-to-pick-up state.

## When a skill says "fetch the relevant ticket"

`stories-get-by-id` with the numeric id.

## Wayfinding operations

Used by `/wayfinder`. The **map** is an epic; its decision tickets are the epic's
stories.

- **Map**: `epics-create`, named `wayfinder: <destination>` so it reads as a map
  rather than a delivery epic, holding the Destination / Notes / Decisions-so-far /
  Fog body. Update it with `epics-update`.
- **Child ticket**: `stories-create` with `epic` set to the map's id. Record the
  ticket type (`research` / `prototype` / `grilling` / `task`) as a `Type:` line in
  the description rather than a `wayfinder:<type>` label, which would be minted
  workspace-wide.
- **Blocking**: `stories-add-relation` with `relationshipType: "blocked by"`, the
  native relationship Shortcut renders in its own UI.
- **Frontier query**: `stories-search` with `epic: <map>`, `isDone: false`,
  `isBlocked: false`, `hasOwner: false`. First in epic order wins.
- **Claim**: `stories-assign-current-user`, the session's first write.
- **Resolve**: `stories-create-comment` with the answer, `stories-update` to the
  completed state, then append a context pointer (gist plus story id) to the map's
  Decisions-so-far via `epics-update`.

**Why an epic and not a parent story with subtasks.** `stories-create-subtask` gives
real parent/child stories, but `stories-search` cannot filter on a parent, so a map
built that way has no native frontier query and degrades to fetching each child by id.
An epic is the only container the search tool can scope to.

## Server note

Two Shortcut MCP servers exist: a self-hosted one, and the official hosted server at
`https://mcp.shortcut.com/mcp`. The self-hosted server returns a deprecation notice
recommending migration. Tool names and parameters here are verified against the
self-hosted server, so re-verify them against whichever one is connected.
