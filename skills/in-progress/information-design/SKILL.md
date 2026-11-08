---
name: information-design
description: Design technical explanations around the reader's reasoning task. Use for visual explanations, diagrams, quantitative comparisons, and interactive walkthroughs.
metadata:
  credits:
    skill: show-me
    author: Dex Horthy
    organization: Humanlayer
    url: "https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md"
---

Help the reader perform the intended reasoning task: trace behavior, explain a change, compare alternatives, locate a fact, or review an implementation. Assume technical literacy without familiarity with this particular system; adapt to the stated audience.

This skill owns explanatory design. The invoking workflow owns its template, delivery format, storage, persistence, and asset reuse. Apply the standard within that contract, including a PR template or an existing teaching course.

## Frame the explanation

Before choosing a view, identify:

- **Reader task:** what the reader needs to understand or decide.
- **Units:** the parts the explanation is about, named in the system's own vocabulary (its phases, stages, services, components), not in representation types. For a request as broad as "how the system works", these units are the explanation's skeleton.
- **Relationship:** what they must see, such as sequence, accumulation, ownership, dependency, comparison, or state change.
- **Inference:** what they should be able to work out afterward, such as what survives another phase transition or which option meets a constraint.

State the reader task, units, and inference in one line, in your reply or at the top of the artifact, so the reader can correct the framing before the detail builds on it. The teaching order follows the reader task, not the richest available data.

Choose the simplest representation that preserves the relationships needed for that inference. For an explicitly visual request, the main visual carries essential explanatory work; prose supplies interpretation and qualifications.

## Choose the teaching order

Establish the thesis early and give the reader an overview before the mechanics. Aim for a thesis in ten seconds and the shape of the explanation in sixty; fit the caller's format rather than imposing opening paragraphs.

- **Mechanism:** start with a concrete input and outcome, then reveal the state or interactions that explain it. Introduce terminology as it becomes useful.
- **Comparison:** establish the decision and criteria, then align the alternatives against them.
- **Performance:** lead with the measured constraint, then connect the aggregate pattern to representative calls or events. Call something a bottleneck only when evidence establishes what it constrains.
- **Reference or review:** lead with the lookup target or change, then expose the detail needed to use or assess it.

Keep the same example recognizable from overview to detail. Put secondary payloads, benchmark grids, settings, and supporting proofs behind details or in an appendix.

## Choose a representation

The choices below are candidates, not mandatory formats. Combine views when they answer distinct questions or connect an overview to a concrete instance.

| Relationship or reader task | Useful views |
| --- | --- |
| Stages that hand off work | Aligned stage cards (gets / does / passes on), with the handoff payload labeled between them |
| Order, duration, overlap | Timeline; swimlanes when actors matter |
| Messages across boundaries | Sequence diagram |
| State through execution | Aligned before/after states, storyboard, execution stepper |
| Accumulation, reset, retention | Message stacks or ranges showing added, retained, and replaced parts |
| Quantitative differences or trends | Aligned bars, lines, small multiples |
| Coverage, gaps, repeated reads | Range diagram or coverage matrix |
| Ownership, dependency, connectivity | Component diagram or topology |
| Exact values or categorical comparison | Table with units and concise text where useful |
| Algorithm or runtime call hierarchy | Pseudocode or call tree |
| UI or file responsibility | Component tree or shallow annotated file tree |
| Implementation change | Diff over the relevant code, tree, or state |
| Mostly new code or a copyable target | Complete relevant block |

For example, a call tree shows who invokes whom; a sequence diagram shows exchanges across actors; successive message stacks show what is resent or discarded. Choose according to the question, even when all three describe the same system.

For implementation review, keep literal names and enough surrounding structure to expose the change:

```diff
 on(save)
   if content is unchanged
     return cached result
   write new content
+  invalidate cache
   return fresh result
```

## Construct the visual

- **Preserve identity.** Keep names, shapes, positions, and meaningful colors consistent across related views. Distinguish entity identity from emphasis on the current change.
- **Expose change.** Show added, removed, retained, and transferred state. Align successive states so the reader can compare them without mentally rebuilding the layout.
- **Explain connections.** Label arrows with the action or payload they represent. Make boundary crossings and handoffs explicit where they affect the inference.
- **Compare fairly.** Use consistent scales for comparable quantities. Quantitative size and position follow the data; show units, baselines, and relevant scale changes. Mark schematic layouts as unscaled when size could be mistaken for quantity.
- **Label locally.** Place explanations beside the relevant marks or parts. Use direct labels where they remove a legend lookup.
- **Layer detail.** Keep each view coherent. Split or simplify when labels, crossings, or competing relationships obscure its question; preserve links between overview and detail. Node and control counts are simplification heuristics, not limits.
- **Color semantically.** Use neutral structure and a small palette for meaningful entities, categories, or emphasis. Pair color with labels or shapes, with readable contrast in the intended themes.

Use interaction for a specific investigative benefit. When considering selection, stepping, or parameter changes, read [WIDGETS.md](WIDGETS.md) to assess eligibility and construct the interaction.

## Write and substantiate

Name the actor and the action. Use the domain's real names and examples, explain unfamiliar terms, and keep prose near the evidence it interprets. Use short, front-loaded labels when they help scanning.

Trace factual claims and quantitative figures to sources, code, or recorded events. Provide inspectable references where possible. Label invented data or schematic examples _illustrative_; identify estimates and assumptions where they affect interpretation. State a source gap rather than filling it with a guess.

Preserve measurement meaning throughout the headline, labels, and conclusions: quote matching, semantic support, and successful execution are different outcomes. Distinguish observations, implementation facts, and interpretations. A missing term in a text search alone does not establish that a mechanism is absent.

Tables support both lookup and comparison: include units and concise text where needed; distinguish unknown values from values that are not applicable. State excerpts and omitted context explicitly when shortening literal payloads.

## Check the explanation

Check whether the representation supplies the information needed for the intended inference.

**Coverage** comes first: every unit the overview names has its input, action, and output on the page. For each handoff between units, answer one counterfactual from the page alone ("if unit N's output changed, what does unit N+1 see?"). A unit you cannot answer for is a gap; fill it before polishing anything else.

Then, for a mechanism, trace another case; for a comparison, check the decision against its criteria; for a reference or review, check that the needed fact or change can be located. This is an artifact check, not proof of reader comprehension or a requirement to add a quiz. When revising an artifact, run this whole check again, not only the rules that changed.

For rendered artifacts, inspect an intended desktop width and a narrow width. Check labels, reading order, scales, and representative interaction states. For inline diagrams, inspect the available rendering without creating a separate page solely to satisfy this check. When rendering is unavailable, check the source and report what remains unverified; delivery can proceed. Claim reader comprehension only when it has actually been tested.
