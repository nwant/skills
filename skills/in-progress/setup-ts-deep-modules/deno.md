# Deno path: `deep_modules.ts`

For Deno repos. The steps in `SKILL.md` point at the sections here. The checker is one zero-dependency file, copied into the repo and committed, so the owner can read every line; it adds nothing to `deno.json` `imports`.

**Existing checker**: a `tools/deep_modules.ts`. If one exists, do **not** overwrite it. Diff it against [`deep_modules.ts`](./deep_modules.ts) formatted with the repo's `deno fmt`, show the user the differences, and replace it only if they agree, carrying their edited constants (`PACKAGES_ROOT`, `SCAN_PATHS`, `LAYERING`) into the new copy. It is code, not data, so there is no merge.

## Install

Copy [`deep_modules.ts`](./deep_modules.ts) to `tools/deep_modules.ts`, then run `deno fmt tools/deep_modules.ts` so it follows the repo's own `fmt` options. Nothing is downloaded: the checker shells out to the repo's own `deno info --json`.

**Done when:** `tools/deep_modules.ts` exists and matches the shipped file apart from its constants and formatting.

## Config

Edit the three constants at the top of `tools/deep_modules.ts`:

- `PACKAGES_ROOT`: the root from step 1.
- `SCAN_PATHS`: the paths the repo's `deno check` already gets, read once now from the `check` task in `deno.json` (e.g. `deno check src/ test/` → `["src", "test"]`). The checker walks every source file under them, so files nobody imports are still checked. If the repo has no `deno check` paths, use `["."]`.
- `LAYERING`: leave empty unless the user asks for layering.

**Done when:** the constants match the repo, and `deno run --allow-read=. --allow-run=deno tools/deep_modules.ts` runs and reports a nonzero module count.

## Wire

In `deno.json`:

- Add a task: `"check:boundaries": "deno run --allow-read=. --allow-run=deno tools/deep_modules.ts"`.
- Append `&& deno task check:boundaries` to the `check` task.
- Add `tools/` to the `deno check` paths in `check`, so the checker is type-checked like everything else.
- If `fmt.include` or `lint.include` is set, add `tools/` to it.

If there is no `check` task, add one that runs `deno check`, `deno lint`, `deno fmt --check`, then `deno task check:boundaries`, and tell the user to run `deno task check` in CI.

**Done when:** `deno task check` runs the boundary check, and passes with `tools/deep_modules.ts` included in its typecheck, lint, and format.

## Example

`<packages-root>/example/mod.ts` (entry point; `mod.ts` is Deno's habit, any root file works), `lib/impl.ts`, and `tests/example_test.ts`, which imports only `../mod.ts` and uses `Deno.test`. Imports carry explicit `.ts` extensions.

## Run

`deno task check:boundaries`. Exit 0 is clean, 1 is violations, 2 means the checker could not run (no `deno` on PATH, no modules found under `SCAN_PATHS`, or a `deno info --json` graph version it does not know). Exit 2 is a broken setup, never a pass.

## README

Name the command (`deno task check:boundaries`) and say where layering rules go (`LAYERING` in `tools/deep_modules.ts`). State the permissions honestly: the checker reads the repo and runs `deno info`, and that child `deno` process is not bound by the parent's flags; it reads files and, for uncached `jsr:`/`npm:`/`https:` modules, fetches them, and it runs no code.
