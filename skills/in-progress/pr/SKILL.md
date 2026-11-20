---
name: pr
description: "Use when writing a PR body."
---

Use this template for writing the PR body:

```markdown
## Summary

<diagram, diff-sketch, or tree>

## Evidence

- **Before:** <screenshot/output/failing test run>
  **After:** <screenshot/output/passing test run>

## Merge Danger

**Door:** <one-way or two-way>

<optional: description>

**Blast Radius:** <one-word description>

<optional: potential ramifications of merge>
```

## Sections

Write the PR in plain English for a reader who has none of this conversation's context: say what changes for the people who use the thing (and why) before the details, explain any term outside the project's glossary, and name things instead of pointing at the conversation. No filler: skip preambles, recaps, hedging, and praise, and cut any sentence the reader would not miss. The reader may not be a developer and opens only this PR, so spell out anything they must do to try it. Use the user's domain language from `CONTEXT.md`.

### Summary

Call the Skill tool with "information-design" to design the Summary for reviewing the change. Keep this PR template as the delivery format.

### Evidence

Concrete evidence that the change works. Show a before and after.

Screenshots are S-tier - when the environment is set up for it and the change is visual.

Execution-based evidence is A-tier. Test results, console output. Show the exact test that now fails and passes, using pseudocode.

### Merge Danger

Describe whether it's a one-way or two-way door. You can walk back through two-way doors, but not one-way doors. A PR that is cheap to roll back is lower risk. Changes that involve destructive actions or hard-to-reverse decisions are one-way doors.

The blast radius is the potential impact or scope of the changes introduced by this PR. Consider all possibilities. Examples are layout shift, breakages for consumers, mobile responsiveness, etc.
