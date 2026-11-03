# Interactive explainers

A widget earns its place when the point turns on one to three continuous variables and the sources give real numbers for how the output moves with them. Anything else is a table.

- **One to three controls.** Expose only the independent variables that drive the insight: sliders, toggles, or a step button. Hardcode everything else at a sourced default, and list those defaults on the page.
- **Live.** Every control recomputes the visual, the equation values, and the output metrics on `input`, with no Run button.
- **Interesting default.** Load at the boundary where the tension shows: just short of the memory ceiling, right where recall starts to fall. Put one sentence above the controls naming what to drag and what to watch.
- **Sourced model.** The function that maps controls to outputs comes from the sources. Show the formula on the page and cite it. Where you interpolate between published points, say so.
- **Proportional.** Bar lengths, areas, and positions scale with the real quantity, from a zero baseline unless the page says otherwise.
- **Colour by role.** Slate for ordinary structure, teal `#0f766e` for the novel mechanism, amber `#b45309` for bottlenecks and failure states.
- **One file.** A single self-contained HTML file with inline CSS and JS and no network requests, so it opens from disk and survives being archived.
