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

**The ticket names its repos. Name each one aloud before its commit.** Committing to
whichever repo the working directory happened to be is silent and hard to unpick, so
say which repo you are about to commit to, and commit **once per repo the ticket
names** — and only to those. A repo the ticket does not name is a repo to stop and ask
about, never one to guess at.

This is about reading the ticket, not about working out where you are: repo identity
comes from the ticket, so nothing is resolved from the environment to honour it.

A ticket that names several repos is the normal case in a workspace rather than an
exception, and splitting it across runs is not free: where the same file is live in more
than one repo, landing one side per run is how the copies drift, and no CI in either
repo can see it.
