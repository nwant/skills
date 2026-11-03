# In Progress

Beta. These skills are public on purpose: try them and tell me what breaks. They're kept out of the top-level README until they graduate to a stable bucket, they get no docs pages, and they can change or disappear without warning.

`link-skills.sh` installs these along with the promoted set: it links every bucket except `deprecated/` and `misc/`.

```bash
./scripts/link-skills.sh
```

- **[loop-me](./loop-me/SKILL.md)**: Grill yourself into implementable workflow specs over multiple sessions, using the current directory as a stateful workspace. User-invoked.
- **[writing-beats](./writing-beats/SKILL.md)**: Shape an article as a journey of beats, choose-your-own-adventure style. Pick a starting beat, write only that beat, then pivot to the next, until the article reaches a natural end.
- **[writing-fragments](./writing-fragments/SKILL.md)**: Grilling session that mines you for fragments (heterogeneous nuggets of writing) and appends them to a single document as raw material for a future article.
- **[writing-shape](./writing-shape/SKILL.md)**: Take a markdown file of raw material and shape it into an article paragraph by paragraph, arguing format choices at each step.
- **[claude-handoff](./claude-handoff/SKILL.md)**: Hand the current conversation off to a fresh background agent that picks up the work immediately, seeded with a handoff summary via `claude --bg`. User-invoked.
- **[setup-ts-deep-modules](./setup-ts-deep-modules/SKILL.md)**: Enforce deep modules in a TypeScript repo, Node or Deno: each package's implementation hidden in subfolders, reachable only through its entry-point files, tests exercising it through those. User-invoked.
- **[implement-spec](./implement-spec/SKILL.md)**: Implement the result of `/to-spec` and `/to-tickets` on one integration branch. Works the tickets as a task graph rather than a list, running a fresh implementer subagent per ticket across the ready frontier for maximum concurrency, then one `/two-axis-review` over the branch. User-invoked.
- **[retro](./retro/SKILL.md)**: Suggest improvements to the coding agent's environment (steering files, coding standards, automated checks, tooling) after a session. Mechanical mistakes become deterministic checks; judgement calls become coding standards. User-invoked.
- **[information-design](./information-design/SKILL.md)**: The shared standard for explaining technical material: BLUF and the ladder of abstraction, sourced figures, picking the smallest view, diagram colour by role, and rules for interactive explainers. `pr`, `show-me`, and `synthesize` all load it.
- **[synthesize](./synthesize/SKILL.md)**: Turn a pile of sources (papers, URLs, notes) into a Synthesis: a scannable, cited document, with an optional interactive explainer and a fresh-context citation check before it's done. User-invoked.
- **[show-me](./show-me/SKILL.md)**: Explain the current topic visually, inline in the chat, falling back to one throwaway HTML page outside the repo. User-invoked.
- **[pr](./pr/SKILL.md)**: Write a PR body built for fast human review: the smallest visual that shows the change, before/after evidence, and a one-way or two-way door call.
