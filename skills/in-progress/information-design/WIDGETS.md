# Interactions

Read this reference when evaluating or building selection, stepping, or parameter changes in a Visual explanation. The shared evidence and visual-construction rules live in `SKILL.md`.

## Choose the interaction

Static views are sufficient when they expose the relationship clearly. Add interaction when it lets the reader investigate something that static views make difficult. Identify the question the control answers before building it; make the initial view useful before input.

| Mode | Reader action | Evidence required |
| --- | --- | --- |
| Inspect | Select an event, entity, range, or assertion to reveal detail | Recorded or sourced data, with a traceable link between the selection and its detail |
| Step | Advance or scrub through execution or a state transition | Recorded states or explicit executable rules; label schematic examples |
| Experiment | Change inputs and inspect consequences | A disclosed model with defensible parameters, assumptions, and limits |

Choose the mode according to what actually changes. Selecting a recorded call does not simulate another run. A hypothetical compaction control cannot claim latency or quality gains unless its model supports those predictions.

## Make investigation direct

- **Meaningful controls.** Expose only choices that serve the question. Keep unrelated settings fixed; disclose defaults and assumptions that affect interpretation. Discrete selectors, toggles, and step buttons are as valid as continuous sliders.
- **Linked views.** When several views describe the same selection, update their highlights and details together. Preserve the selected entity's identity and its connection to the overview.
- **Immediate feedback.** Update the affected views on selection or input. Recompute equations and metrics only where the model calls for them; recorded-state inspection needs no formula or invented numerical model.
- **Useful default.** Start at a representative state, contrast, or boundary that exposes the question. Put a short instruction beside the control naming what to change and what to watch.
- **Purposeful motion.** Use motion to explain a transition. Allow pausing, stepping, or static comparison where inspection matters, and respect reduced-motion preferences.
- **Accessible operation.** Label controls, support keyboard and touch use, and keep essential evidence available without hover. Provide a text equivalent for the main visual and announce meaningful selected-state changes without narrating every animation frame.

For experiments, show the governing relationship or algorithm and cite its source or derivation. Identify interpolation, estimates, and limits. Keep the displayed values and visual state consistent with that model.

## Package and verify

Follow the caller's delivery and asset contract. A standalone artifact defaults to one offline HTML file with inline assets; an existing course can reuse its local components, and an active rendering environment supplies its own output contract.

Exercise representative states, including the transition or boundary central to the explanation. Verify that the controls update the evidence they claim to control, selected details correspond to the selected item, and the initial and changed states remain readable at intended and narrow widths. Follow `SKILL.md` when rendering cannot be inspected.
