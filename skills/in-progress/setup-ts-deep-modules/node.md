# Node path: dependency-cruiser

For Node repos (npm, pnpm, yarn, bun). The steps in `SKILL.md` point at the sections here.

**Package manager**: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lockb` → bun, else npm. Use it for every command below (`pnpm`/`yarn`/`npm run`/`bunx`).

**Existing checker**: a `.dependency-cruiser.*` file. If one exists, do **not** overwrite it: merge the rules and the options from [`dependency-cruiser.config.cjs`](./dependency-cruiser.config.cjs) in (including `tsPreCompilationDeps: true`), and tell the user what you added.

## Install

Install `dependency-cruiser` as a devDependency with the detected package manager. Then run `depcruise --info` and confirm the `typescript` transpiler row shows ✔. dependency-cruiser parses `.ts` only with a TypeScript version inside its supported range; outside it, it cruises zero `.ts` modules and reports success. If the row shows `x`, tell the user which TypeScript range it supports and stop until it does.

**Done when:** `dependency-cruiser` is in `devDependencies` and `depcruise --info` shows typescript ✔.

## Config

Copy [`dependency-cruiser.config.cjs`](./dependency-cruiser.config.cjs) to the repo root as `.dependency-cruiser.cjs`. Set `PACKAGES_ROOT` to the root from step 1. The rules are path-depth based and extension-agnostic, so nothing else needs adapting. Use `.cjs` (not `.js`) so `module.exports` works even in `"type": "module"` repos.

The config's `$1` back-references (dependency-cruiser's group matching) are what let a package reach its own internals while outsiders can't. Keep them; flattening them into per-package rules means editing the config for every new package.

**Done when:** `.dependency-cruiser.cjs` exists with the correct `PACKAGES_ROOT`, the five forbidden rules, and `tsPreCompilationDeps: true`.

## Wire

Add a `lint:boundaries` script: `depcruise src` (or `depcruise <packages-root>` in a repo without `src/`). Fold it into the umbrella script that already runs typecheck (e.g. `check` / `ci` / `validate`). If there is no umbrella script, add `lint:boundaries` alone and tell the user to include it in CI.

**Done when:** `lint:boundaries` exists and runs as part of the same command as typecheck.

## Example

`<packages-root>/example/index.ts` (entry point), `lib/impl.ts`, and `tests/example.test.ts`, which imports only `../index`.

## Run

`<pm> run lint:boundaries`. The summary line reads `N modules, M dependencies cruised`; `0 modules` is a failure of the setup, not a pass.

## README

Name the command (`<pm> run lint:boundaries`) and the config file (`.dependency-cruiser.cjs`, where layering rules go).
