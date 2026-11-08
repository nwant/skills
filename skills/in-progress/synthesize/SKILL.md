---
name: synthesize
description: Turn a pile of sources (papers, URLs, notes) into a scannable, cited Synthesis document.
disable-model-invocation: true
argument-hint: "Sources to synthesize: paths, URLs, or a research file"
---

A **Synthesis** turns a fixed pile of sources into one document a reader can scan in a minute, with every figure traced to a source. You write up what you were given; finding more is `/research`'s job.

## 1. Read the pile

Read every source the user named, end to end: files, URLs, an earlier research file, an old note being rewritten. Number them `[1]`, `[2]`, … in the order you will list them. Keep to the pile: when a section needs something no source holds, record it as a **gap** rather than searching for it.

Done when every source is read and numbered, and the gaps are listed.

## 2. Load the standard

Call the Skill tool with "information-design" for the explanatory design. This workflow owns source boundaries, the saved document, and citation review.

## 3. Frame

Before writing, name for yourself:

- **Reader task**: what the Synthesis should help the reader understand or decide.
- **Evidence**: the findings and relationships the source pile supports, and the gaps it leaves.
- **Design**: apply the shared standard to choose the teaching order and representations. When considering interaction, follow its pointer to the interaction rules before judging eligibility.

## 4. Write

Ask where to save if the repo has no convention for notes; otherwise match it. Use this metadata, then write the explanation in the order chosen for the reader's task:

```markdown
---
title: <title>
date: <YYYY-MM-DD>
tags: [<tag>, ...]
sources:
  - <url or path of [1]>
  - <url or path of [2]>
---

<central finding, sections, and views selected using information-design>
```

Include sections only when they serve the reader's task and the sources support them. Cite inline with the source number, `[2]`, after each claim it supports. Keep gaps explicit.

## 5. Deliver or offer interaction

If a useful interaction was requested, build it within that scope using the shared interaction rules. When a useful interaction was not requested, deliver the static Synthesis and offer the optional interaction in one line: the question it answers and what the reader can inspect, step through, or change. Build that companion after the user agrees, as one HTML file beside the Synthesis, linked from the relevant section. When static views suffice, deliver the Synthesis without proposing a companion.

## 6. Check the citations

Dispatch a subagent with a fresh context window. Give it the Synthesis path and the source list, and ask it to read both and report every figure and factual claim that its cited source does not support, or that carries no citation and is not labeled _illustrative_. It reports; it does not edit.

For each claim it reports: add the right citation, label it _illustrative_, or cut it. Done when every reported claim is resolved, and the subagent's report is the evidence, not your own re-read.

## 7. Report

Tell the user the file path, any companion path, and the gaps. For gaps worth filling, suggest running `/research` on them and then `/synthesize` again with the new file added to the pile.
