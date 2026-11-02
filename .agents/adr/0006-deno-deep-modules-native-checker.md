# Deno deep modules use a native checker, not dependency-cruiser

`setup-ts-deep-modules` enforces its boundary rules on Deno with its own checker, `deep_modules.ts`, built on `deno info --json`, rather than running dependency-cruiser through `npm:`. dependency-cruiser does not understand `deno.json` import maps or `jsr:` specifiers, so a deep import written through a local alias (`"#/": "./src/"`) would go unresolved and pass silently: the one failure the skill exists to prevent. Running it also takes `-A` and an npm toolchain into repos that may allow only `jsr:@std/*`. The native checker resolves through Deno's own resolver, runs with `--allow-read=. --allow-run=deno`, and has no dependencies. Node repos keep dependency-cruiser, which handles their resolution (`tsconfig` paths, package `exports`) better than anything we would write.

## Considered Options

- **dependency-cruiser via `npm:`**: no code to maintain, mature cycle reporting, exact `$1` semantics; rejected for the silent pass on import-map aliases and the permissions.
- **A `deno lint` plugin**: free wiring into `deno lint`, but it sees one file at a time with raw specifiers, so no import-map resolution and no cycle detection.
- **One shared `rules.ts` for both runtimes** (dependency-cruiser reduced to a graph extractor): a single source of truth, but it rewrites a working Node path, drops dependency-cruiser's own rule engine and config merging, and needs a minimum Node version, all to remove about 40 duplicated lines.

## Consequences

The five rules now exist twice. `test/parity.ts` runs both checkers over one violation tree and asserts both match a hand-written expected list; that is the guard against drift. If the rules grow past fixed path predicates plus name-pair layering (rule logic a user writes per repo), the duplication stops being cheap: collapse into one shared `rules.ts` at that point.

`deno info --json` is marked unstable by Deno. The checker accepts only the graph versions it knows and exits 2 on any other, so a format change breaks loudly instead of reading as an empty, passing graph.
