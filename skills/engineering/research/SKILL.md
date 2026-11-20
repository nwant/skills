---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Spin up a **background agent** to do the research, so you keep working while it reads. Start it with a fresh context window.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source. Write it in plain English for a reader who has none of this conversation's context: say what it is and why it matters before the details, explain any term outside the project's glossary, and name things instead of pointing at the conversation. No filler: skip preambles, recaps, hedging, and praise, and cut any sentence the reader would not miss.
3. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it somewhere sensible and say where.

When it reports back, give the user the file's path and tell them they can run `/synthesize` on it to turn the findings into a Synthesis.
