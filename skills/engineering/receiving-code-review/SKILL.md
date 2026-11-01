---
name: receiving-code-review
description: Weigh review feedback before acting on it. Use when code review findings arrive, from the user, a PR, or a review subagent such as two-axis-review, before implementing any of them.
---

# Receiving code review

Each review finding is a **claim** about the code. Check it against the codebase before acting on it, then answer in technical terms: fix it, push back with evidence, or ask. A finding is right or wrong on the code, whoever wrote it.

## The sequence

1. **Gather all of it** before acting on any of it. On a GitHub PR, feedback lives in three places, and the important part is often not in the first: inline comments (`gh api repos/{owner}/{repo}/pulls/{pr}/comments`), review bodies (`gh api repos/{owner}/{repo}/pulls/{pr}/reviews`), and the conversation (`gh api repos/{owner}/{repo}/issues/{pr}/comments`).
2. **Restate** each finding as a technical requirement. Where any finding is unclear, ask about it before implementing any of them: findings are often related, and a fix built on a partial reading is a wrong fix.
3. **Verify** each against the codebase. Is it true here? Would the fix break something that works now? Is there a reason the code is the way it is? Does the fix hold on every platform and version the project supports?
4. **Decide** each one: fix, push back, or ask.
5. **Fix** in order: blocking (breakage, security), then simple, then complex, testing each fix as it lands. Before reporting any of them fixed, call the Skill tool with "verification-before-completion".

Done when every finding has an outcome you can point to: fixed (and where), pushed back (and why), or asked (and what).

## By source

| Source | Stance |
| --- | --- |
| The user | Trusted. Implement once you understand it; ask where the scope is unclear. |
| A human reviewer or PR bot | Outside this conversation's context. Verify each finding before acting on it. |
| A review subagent | Also outside the conversation: it saw the diff, not the decisions behind it. Verify each finding the same way. |

**Findings from `two-axis-review`** come under `## Standards` and `## Spec`. Work them as two lists, never merged into one ranking, because the separation is what stops one axis masking the other. A Spec finding that would move the code away from the spec, or any finding that overrules a decision the user made, goes to the user before it touches the code.

## Pushing back

Push back when a finding would break working behaviour, misses context the reviewer lacks, asks for a feature nothing uses, is wrong for this stack, or contradicts a recorded decision. Make the case with evidence: the failing test, the call site, the constraint.

Before building out a suggested "proper" version of something, check whether anything uses it. A search that comes back empty is a claim about the search: show it finding a caller you know exists before treating the silence as "unused", and propose the removal rather than making it.

Where you cannot verify a finding, say what you would need to: "I can't confirm this without the production config. Investigate, or proceed as written?"

## Responding

Answer with substance: the requirement restated, or the fix and where it landed ("Fixed: null check before the parse, `parser.ts:42`"). The fix is the acknowledgement, so the reply carries the change rather than praise or thanks. When your pushback turns out wrong, say so in one line with what you checked, and fix it.

On GitHub, reply to an inline comment in its own thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a top-level PR comment.
