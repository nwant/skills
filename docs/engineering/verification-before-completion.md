# verification-before-completion

## What it does

`verification-before-completion` makes the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) prove a claim before it makes it. Before saying work is done, fixed, or passing, before committing or opening a PR, and before trusting a [subagent](https://www.aihero.dev/ai-coding-dictionary/subagent)'s report, it names the command whose output would prove the claim, runs it in full, reads all of it, and reports what the output actually shows.

Only output produced in this turn counts as evidence. An earlier run, a subagent saying "done", a commit message, and "should pass" are all claims about evidence. That is the whole difference from the default, where an agent that has just written a fix tends to announce it fixed.

## When to reach for it

Type `/verification-before-completion`, or the agent reaches for it automatically when a task fits. It fires on a moment, not a step:

| The moment | What it checks |
| --- | --- |
| About to say "done", "fixed", "passing", or anything that implies it | The command that proves that exact claim, run now |
| About to commit, open a PR, or close a ticket | The full suite and build, not the file you touched |
| A subagent reports success | The diff on the branch and a test run there |
| A commit in history looks like it already did the work | `git show` on that commit, not its message |

## Fresh evidence and provenance

The leading idea is **evidence before claims**, and its sharper half is **provenance**: output proves something only about whatever produced it. Three failures fit inside "I ran a command and read the output" and still end in a false claim:

- **Silence read as a negative.** An empty search or an empty log means "absent" or "the instrument is broken". The skill wants a positive control first: show the search finding something you know is there.
- **Your own probe read as the system acting.** A probe you triggered by hand proves the probe works, not that the system ever triggered it.
- **A restore that undoes the work.** In a break-and-restore loop on uncommitted changes, `git checkout -- <file>` reverts the feature along with the break, and every check after it runs against the old code.

## Common questions

**It ran a check, read the output, and was still wrong. How?**

Because the output came from the wrong place. The cases reported against the skill this one is adapted from were all provenance failures: a log entry the agent had written itself while testing its probe, read as proof the system fired; the same probe staying silent because it wrote to a different temp path, read as proof the system never ran. Every rule about running and reading was obeyed. The **Provenance** section exists for exactly this, so when a verification surprises you, ask what produced the output before asking what it says.

**Its verification loop wiped out my uncommitted changes.**

A reported failure: the loop broke files on purpose to see tests go red, then restored each with `git checkout`, which also reverted the half hour of uncommitted work under test. The checks that followed passed and failed for the wrong reasons. The skill now restores from a copy taken at the start of the run unless the work is committed, and confirms each break landed before trusting the red. If you are about to let an agent run a mutation loop on uncommitted work, commit first anyway.

**A commit already says it fixed this. Is it done?**

Not until `git show` says so. A commit message is a claim about the diff. One reported case had a commit titled exactly like the fix about to be written, and it touched only documentation. A commit title that restates the current task almost word for word is a reason to look harder, because a plan-only commit looks exactly like that.

**Why run the whole suite for a one-line change?**

Because the break is often far away. In one report, adding a fourth card to a collection broke an unrelated end-to-end test that asserted there were three, cascading into eighteen failures. The nearest test file passed throughout.

**What if there is nothing to run?**

Then the honest report names what went unverified and why: no test harness for that layer, a step only you can take, a service the agent cannot reach. That is a complete answer. The alternatives (claiming it anyway, or quietly installing a harness nobody asked for) are the failures the skill exists to replace.

## It's working if

- Status messages quote output ("34/34 pass, exit 0") rather than "should work" or "looks good".
- When a subagent says it finished, the next thing in the trace is a diff or a test run, not the next task.
- Where something could not be checked, the message says so, and says why.
- A surprising result gets a positive control (the search shown finding a known match) before anyone acts on it.

## Where it fits

`verification-before-completion` is a **model-invoked discipline** that runs underneath every flow rather than being a step in one. [implement](./implement.md) calls it explicitly before committing, and the in-progress `implement-spec` calls it before counting a subagent's ticket complete. Its rows for regression tests, new guards and requirements defer to [tdd](./tdd.md), [diagnosing-bugs](./diagnosing-bugs.md) and the two axes of [two-axis-review](./two-axis-review.md) rather than repeating them. Its partner on the review side is [receiving-code-review](./receiving-code-review.md). [which-skill](./which-skill.md) maps the whole set.
