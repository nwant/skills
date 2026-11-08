---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

If the user passes a ticket reference, fetch it from the issue tracker as `docs/agents/issue-tracker.md` describes, and state its title before starting. If that file is missing, say so and tell the user to run `/setup-skills`; never guess the tracker. If the reference is ambiguous, ask.

Call the Skill tool with "tdd" where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite at the end.

Once done, call the Skill tool with "two-axis-review" to review the work. Then call the Skill tool with "receiving-code-review" to work through its findings.

**The spec describes everything the diff does.** Before committing, read the diff for behavior the spec doesn't describe or contradicts (a new event, command, field or edge rule), whether the user approved it or you added it, and update the spec file in the same change. Otherwise the next ticket's agent reads the old spec and undoes it.

Before committing, call the Skill tool with "verification-before-completion". Its evidence is a fresh full-suite run made after the review fixes, not the earlier one.

Commit your work to the current branch, unless the repo's own instructions require a branch per ticket: then create that branch first.

**Name the repo before you commit, and refuse to guess.** A ticket may name a repo
other than the one you are standing in, and committing it to whichever repo the
working directory happened to be is silent and hard to unpick. State which repo you
are about to commit to, and if the ticket names a different one, stop and say so
rather than orchestrating a change across several. One ticket, one repo, per run.

This is about reading the ticket, not about working out where you are: the ticket
names its repo, so nothing has to be resolved to honor it.
