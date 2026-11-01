# receiving-code-review

## What it does

`receiving-code-review` is how the [agent](https://www.aihero.dev/ai-coding-dictionary/agent) takes review feedback on its own work. It gathers every finding first, restates each one as a technical requirement, checks it against the codebase, and only then fixes it, pushes back with evidence, or asks you.

Each finding is a claim about the code, to be verified like any other. That is the difference from the default, where an agent handed a list of review comments agrees with all of them and starts editing, including the ones that are wrong for this codebase.

## When to reach for it

Type `/receiving-code-review`, or the agent reaches for it automatically when review findings arrive. Reach for it whatever the source:

| Findings from | How they are treated |
| --- | --- |
| You | Trusted: implemented once understood, with a question where the scope is unclear |
| A human reviewer or PR bot | Verified one by one before anything changes |
| [two-axis-review](./two-axis-review.md) or another review [subagent](https://www.aihero.dev/ai-coding-dictionary/subagent) | Verified the same way: the subagent saw the diff, not the decisions behind it |

For *giving* a review, use [two-axis-review](./two-axis-review.md) instead. This skill is the receiving half.

## Restate, verify, then act

The leading idea is that a finding is a **claim**, and the sequence is the one you would use on any claim: restate it so you know what it asks, **verify** it against the code, then act. Two rules make the sequence hold up:

- **Gather everything before acting on anything.** Findings are often related, so an unclear item stops the whole batch until it is answered, rather than the clear items being fixed around it.
- **Every finding gets an outcome.** Fixed and where, pushed back on and why, or asked and what. Nothing is silently dropped, and nothing is agreed with and left undone.

Findings from `two-axis-review` keep their two axes as separate lists. A finding that would move the code away from the spec, or overrule a decision you made, comes back to you before it touches the code.

## Common questions

**It proposed deleting code that nothing calls, and the code was live.**

A reported failure in the skill this one is adapted from: asked to build out a "proper" version of something, the agent searched for callers, got nothing back, and proposed removing it. The search had silently missed files. An empty result is a claim about the search, so the skill now shows the search finding a caller it knows exists before reading silence as "unused", and proposes a removal rather than making one.

**It answered the inline comments and missed the important feedback.**

On GitHub, a PR's feedback lives in three places: inline comments, review bodies, and the top-level conversation. In one reported PR, the inline comments held five findings, the review bodies thirteen more, and the conversation held the security analysis with the most serious ones. Fetching only the first missed most of the review. The skill gathers all three before it starts.

**Does it apply to a review subagent, or only to people?**

Both. It was reported not to fire on a subagent's review in the original, or to fire perfunctorily ("excellent discovery", then straight into edits), because it read as aimed at human reviewers. Here the subagent row is explicit, and [implement](./implement.md) calls it by name on the output of `two-axis-review`, so it does not depend on the agent noticing.

**Why does it never say thanks?**

Because the fix is the acknowledgement. A reply that says what changed and where ("Fixed: null check before the parse, `parser.ts:42`") tells the reviewer more than agreement does, and it keeps the response about the code.

## It's working if

- Replies to a review restate the requirement or name the fix and its location, rather than agreeing.
- At least some findings get pushed back on with a test, call site, or constraint cited, where they deserve it.
- When anything in a batch is unclear, the agent asks before editing any of it.
- At the end, every finding has a visible outcome: fixed, pushed back on, or asked about.

## Where it fits

`receiving-code-review` is a **model-invoked discipline** underneath the flows, not a step in one. [two-axis-review](./two-axis-review.md) produces the findings it most often receives, and [implement](./implement.md) runs the two back to back before committing. Before it reports any fix done, it hands off to [verification-before-completion](./verification-before-completion.md). [which-skill](./which-skill.md) maps the whole set.
