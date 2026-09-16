---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /two-axis-review to review the work.

Commit your work to the current branch.

**Name the repo before you commit, and refuse to guess.** A ticket may name a repo
other than the one you are standing in, and committing it to whichever repo the
working directory happened to be is silent and hard to unpick. State which repo you
are about to commit to, and if the ticket names a different one, stop and say so
rather than orchestrating a change across several. One ticket, one repo, per run.

This is about reading the ticket, not about working out where you are: the ticket
names its repo, so nothing has to be resolved to honour it.
