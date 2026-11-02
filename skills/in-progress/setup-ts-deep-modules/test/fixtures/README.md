# Fixtures

- `violations/`: one source tree with every rule broken at least once.
  `../parity.ts` runs both the Node path (dependency-cruiser) and the Deno path
  (`deep_modules.ts`) over it and asserts they report the same violations.
- `node-npm/` and `deno-std/`: minimal clean repos for the manual acceptance
  run. Copy one to a temp dir, `git init` it, run `/setup-ts-deep-modules`
  there, and confirm the skill reaches step 6's pass → fail → pass with
  `tests-through-entrypoints` named as the failing rule.
