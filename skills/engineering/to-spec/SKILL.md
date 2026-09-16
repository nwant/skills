---
name: to-spec
description: "Turn the current conversation into a spec file in the repo, plus the short tracker item that points at it: no interview, just synthesis of what you've already discussed."
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

The issue tracker and triage label vocabulary should have been provided to you, in `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`. Read both. If either file is missing, say which one and tell the user to run `/setup-skills`; never fall back to a guessed tracker or a guessed label string.

## A spec is a file, not a tracker item

The spec below is long on purpose: the alternatives, the load-bearing decisions and the
reasoning are what make it worth writing. That does not fit in a tracker, and trying is
how it gets damaged. Trackers cap descriptions (Shortcut stories at 10,000 characters),
their editors are not diffable, and nothing reviews a description the way a PR reviews a
file.

So the spec is **a file in the repo**, and the tracker gets a short item that points at
it. Four artifacts, four jobs:

| Artifact | Where | Written | Holds |
| --- | --- | --- | --- |
| **Spec** | a repo file | before the work | problem, alternatives, decisions with rationale, mechanism, testing seams, out of scope |
| **Epic** | the tracker | before, and stays true | why, what changes, what was agreed and when, what is excluded |
| **Ticket** | the tracker | before | one unit of work, its acceptance criteria, a link to the spec |
| **PR body** | the code host | after | what changed, why, how to verify |

**Where the file goes.** `docs/specs/<slug>.md` in the repo the work happens in, or in
the **workspace** when the work spans several repos: same rule as a glossary or an ADR,
so one convention covers all of them. If a tracker id exists already, lead the filename
with it. Call the Skill tool with "workspaces" when a workspace is in effect.

**The spec carries its tracker identity in frontmatter**, because the next reader of it
is a program. `/to-tickets` groups its output under the epic named here rather than
guessing, and a fixed key is reliable where a prose line is a regex waiting to break:

```md
---
epic: 977123
objective: 377141
status: draft
---
```

Three fields, and resist adding more: every mirrored field is one that can go stale with
nothing checking it. `epic` is what `/to-tickets` reads. `objective` is the stable
fallback a search can use, and it is usually set by convention anyway. `status` is
`draft` | `accepted` | `superseded`, the same vocabulary an ADR uses rather than a second
one. **Not the story id**: a spec outlives any single story, so pinning one encodes
something transient.

Write `epic:` as soon as the epic exists. If you are writing the spec first, leave the
key out rather than inventing a placeholder, and add it when you create the epic in the
next step.

**Avoid a tracker's own document feature** unless you have checked what lives there. It
tends to be one flat org-wide space with weak scoping and no versioning, so a dense spec
lands among thousands of unrelated notes and is findable only by guessing its title.

## The epic is at a different altitude

The tracker item that accompanies a spec is **not a summary of it**. It is a broad,
high-level statement of what is being built and why, with the weeds left out, and it
holds whether a stakeholder or the delivery team owns it. The test: it stays true as the
tickets land. If a sentence goes stale when a decision changes, it belonged in the spec.

<epic-template>

## Why

The problem, from the user's or the business's side. Quantify it where you can: a
proportion, a count, a duration. This is the paragraph someone repeats in a meeting.

## What changes

What becomes possible, or stops being painful, described from the outside. Name the
mechanism only where a reader could not otherwise picture the change. Transport,
schemas and interfaces belong in the spec.

## Agreed

Who agreed to this, when, and on what conditions. Dated, because a reader a quarter
later cannot tell a live constraint from a stale one.

## Out of scope

What this deliberately does not cover, so nobody re-opens it as a gap.

</epic-template>

Keep it to something a person reads in one sitting, roughly 1,500 to 2,500 characters.
**End it with the spec file's URL.**

The link runs both ways on purpose, one line each: the spec's frontmatter names the epic,
the epic's description names the spec. Each side answers the question its own reader is
holding, an engineer in the repo asking what this is for and a stakeholder in the tracker
asking where the detail is. Tickets link the spec too, but never the epic separately:
they are already its children, so restating the parent in prose is a second copy that
drifts.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the spec to its file using the template below, and **commit it**. It is a repo
   artifact, so it goes through whatever review the repo requires; a spec nobody could
   comment on is a decision nobody agreed to.

4. Create the **epic** from the epic template above, at altitude, linking to the spec
   file. Apply the `ready-for-agent` triage label - no need for additional triage. Then
   hand off to `/to-tickets`, which splits the **spec**, not the epic, and hangs its
   tickets under it.

<spec-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
