---
name: verification-before-completion
description: Evidence before claims. Use when about to report work as done, fixed, or passing, before committing or opening a PR, and when a subagent reports success.
---

# Verification before completion

A statement that work is done, fixed, or passing is a **claim**, and a claim needs **fresh evidence** behind it: output you ran and read in this turn. An earlier run, a subagent's report, a commit message, and "should pass" are all claims about evidence, never evidence.

## The gate

Run this before any message that says or implies the work is complete, correct, or passing ("done", "fixed", "that does it"), and before committing, opening a PR, closing a ticket, or moving to the next one:

1. **Name** the command whose output would prove the claim.
2. **Run** it in full, now.
3. **Read** all of it: exit code, failure count, stderr.
4. **Report** what it shows. Where it confirms the claim, state the claim with the evidence beside it ("34/34 pass, exit 0"). Where it doesn't, state the actual status and the evidence for that.

Done when every claim in the message has, in this turn, the output that backs it. Where a claim cannot be checked from here (no harness, a step only a human can take, a service you cannot reach), say what went unverified and why, in place of the claim.

## What counts as evidence

| Claim | Evidence | Not enough |
| --- | --- | --- |
| Tests pass | The full suite: 0 failures, exit 0 | An earlier run; the one file you touched |
| It builds | The build or typecheck: exit 0 | A clean linter |
| Bug fixed | The original symptom, re-run, now gone | The code changed |
| The regression test guards the bug | The test seen red without the fix and green with it | The test passing once |
| Requirements met | Each requirement checked against the diff | Tests passing |
| A subagent did the work | The diff on the branch, plus a test run there | The subagent's report |
| It's already done in history | `git show <sha>` touching the code | A commit message saying so |

Two rows already have a home elsewhere. The red-green proof of a regression test is the loop `tdd` runs, and step 2 of Phase 5 in `diagnosing-bugs`. Checking requirements against a spec or ticket is the Spec axis of `two-axis-review`. Use those rather than a weaker check here.

## Provenance

Output proves something only about whatever produced it.

- **An empty result is a claim too.** Silence from a search, a log, or a probe means either "absent" or "the instrument is broken". Show the instrument finding something you know is there (a positive control) before reading its silence as a negative.
- **Output you caused describes your instrument, not the system.** A probe you triggered by hand proves the probe works; it says nothing about whether the system triggered it.
- **Restore from a copy, not from version control.** A break-and-restore loop on uncommitted work restores each file from a copy taken at the start of the run, because `git checkout -- <file>` reverts the work under test along with the break. After each break, confirm it landed before trusting the red.
- **Run the whole suite when you add one more of something.** A new item in a collection breaks counts asserted in tests nowhere near the file you changed.
