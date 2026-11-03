---
name: show-me
description: Help you understand the current topic visually, with compact diagrams, code-shape sketches, and a focused HTML page when those fall short.
disable-model-invocation: true
argument-hint: "Optional: what to show"
metadata:
  credits:
    skill: show-me
    author: Dex Horthy
    organisation: Humanlayer
    url: "https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md"
---

Show the current topic, or the one the user named, so they see it rather than read about it.

1. Call the Skill tool with "information-design".
2. Pick the smallest view from its catalogue that makes the key point clear, and answer inline in the chat. Use the real names, files, and data from the conversation and the codebase.
3. When the point is a visual UI, a layout, a dense state comparison, or a concept Mermaid cannot carry, write one focused, self-contained HTML file instead: a diagram, an infographic, or a short slide deck. Write it to the harness's scratch directory, or the system temp directory if there is none, never into the repo. Open it (`open` on macOS, `xdg-open` on Linux) and give the user its full path.

This is a throwaway explanation. When the user wants to keep it, the durable form is a Synthesis: tell them to run `/synthesize`.
