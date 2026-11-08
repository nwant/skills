---
name: setup-ts-deep-modules
description: Enforce deep modules in a TypeScript repo (Node or Deno) so each package's implementation is hidden in subfolders and reachable only through its entry-point files. User-invoked.
disable-model-invocation: true
---

# Setup TS Deep Modules

Make every package in this repo a **deep module**: a lot of behavior behind a small interface. A package's public surface is its **entry points** (the files at the package root), and everything in its subfolders is hidden. This skill installs a boundary checker and the rules that make the entry points the only way in, then proves the rules bite.

The checker depends on the runtime. Node repos get [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) with [`dependency-cruiser.config.cjs`](./dependency-cruiser.config.cjs). Deno repos get [`deep_modules.ts`](./deep_modules.ts), a zero-dependency checker on top of `deno info --json`, so the import graph resolves exactly as Deno resolves it (import map, `jsr:`, `.ts` extensions) under scoped permissions. Both enforce the same rules under the same names; [`test/parity.ts`](./test/parity.ts) holds them to it.

For the vocabulary (deep module, interface, seam, depth), call the Skill tool with "codebase-design" and use its language throughout.

## The shape this enforces

```
src/packages/
  <name>/
    mod.ts          ← an entry point (public). Import this from outside.
    client.ts       ← another entry point. Packages may expose SEVERAL.
    lib/            ← implementation: hidden from outside, free to import each other.
    tests/          ← co-located tests + fixtures (a subfolder, so private).
```

The public surface is the package's **root files**, not one designated file. The entry-point name follows the runtime's habit (`index.ts` on Node, `mod.ts` on Deno); the rule never looks at names. By convention implementation lives in `lib/` and tests in `tests/`, giving every package the same two-folder shape. The rule itself is general, though: *anything* in *any* subfolder is private, so you never extend the config to add a folder. Tests stay in `tests/` on both runtimes (on Deno, named `*_test.ts` inside it): a test file at the package root would itself count as an entry point.

Four rules, all `error`:

1. **Entry-point boundary**: code outside a package (app code or another package) may import only that package's entry points (its root files), never anything in its subfolders.
2. **Intra-package freedom**: a package's own files import each other freely.
3. **Tests through the entry points**: files under `<pkg>/tests/` may import any package's entry points and their own `tests/` fixtures, but never any package's subfolder internals (not even their own). Integration tests across packages are fine; deep imports are not. Only tests may import a `tests/` folder.
4. **No cycles**: no dependency cycles, anywhere in the scanned code.

Type-only imports (`import type`) count on both runtimes: a deep `import type` is a deep import.

**Entry points, not a barrel.** Because the public surface is *every* root file, a package can expose several small entry points (`mod.ts`, `client.ts`, `server.ts`) instead of funneling everything through one giant entry file. Barrel files that re-export a whole subtree are discouraged; keep entry points small and hide implementation in subfolders.

Layering (which packages may depend on which) is a *different* concern and ships empty: a commented stub in the `.cjs` config, an empty `LAYERING` list in `deep_modules.ts`.

## Steps

### 1. Detect the environment

- **Runtime**:
  - `deno.json` or `deno.jsonc` and no `package.json` → **Deno**: read [deno.md](./deno.md).
  - `package.json` and no `deno.json*` → **Node**: read [node.md](./node.md).
  - Both present → ask the user which toolchain runs this repo's checks (the one whose `check` command CI runs), then read that file. A guess here wires the checker into a toolchain nobody runs.
- **Packages root**: if `src/` exists use `src/packages`, else `packages`. Confirm the choice with the user if the repo already has a different obvious convention.
- **No packages yet**: when the repo has code but nothing under the packages root, leave the existing code where it is. The rules govern only code under the packages root (plus no-cycles everywhere), so existing folders stay legal; deciding which of them should become packages is an architecture call for `/improve-codebase-architecture`, which step 7 points at. A cycle already in that code fails no-circular: stop and report the cycle to the user. Keep the scan scope as step 3 sets it; shrinking it to get a pass hides the cycle rather than fixing it.
- **Existing checker**: the runtime file says what counts as one and how to merge without overwriting.

**Done when:** runtime, packages root, and existing-checker status are all known, and you have read the runtime file.

### 2. Install the checker

Follow **Install** in the runtime file.

**Done when:** the runtime file's Install criterion holds.

### 3. Write the config

Follow **Config** in the runtime file.

**Done when:** the runtime file's Config criterion holds, with the correct packages root.

### 4. Wire it into the checks

Follow **Wire** in the runtime file. Fold the boundary check into the repo's umbrella check command, the one that already runs typecheck. Do **not** touch `tsconfig` or add path aliases. If there is no CI running that command, tell the user to add it; write no workflow file.

**Done when:** the boundary check runs as part of the same command as typecheck.

### 5. Scaffold the example package

Create a committed `<packages-root>/example/` as a copy-me template, with the file names from **Example** in the runtime file:

- An entry point at the root that exports one function delegating to an internal file (so the package is visibly *deep*, not a pass-through).
- `lib/impl.ts`: an internal file in a **subfolder**, imported by the entry point, not reachable from outside.
- A test in `tests/` that imports **only** the entry point and asserts against the public function.

Tell the user this is a starter template to copy or delete.

**Done when:** the example package exists, exposes its behavior through a root entry point, hides `impl` in a subfolder, and its test passes under the repo's existing test runner. If the repo has no test runner, say so and leave the test unrun: adding one is the user's call, not this skill's.

### 6. Prove the rules bite

This is the completion criterion for the whole skill: a checker that doesn't fail on a violation is worthless. Run the boundary check **on its own** (the runtime file's **Run** command), not the umbrella check: lint or typecheck failing first would make a red run prove nothing about the boundaries.

1. Run the boundary check. It must **pass** on the clean example, and its summary must report a nonzero module count. If it fails on code that existed before this skill ran, see **No packages yet** in step 1.
2. Temporarily add a deep import to the example test that the test actually **uses** (e.g. import `impl` from `../lib/impl.ts` and call it). Run the boundary check again; it must **fail**, naming `tests-through-entrypoints` and the test file. A failure under any other rule, or an exit without that rule name, is not this observation.
3. Revert the deep import. Run once more, and it must **pass**.

**Done when:** you have observed a pass, then a fail naming `tests-through-entrypoints`, then a pass again. If step 2 does not fail that way, the rules are not wired correctly, so fix before finishing.

### 7. Document the convention

Write a `README.md` **in the packages folder** (`<packages-root>/README.md`, next to the packages it governs) covering:

- the `<packages-root>/<name>/` layout (entry points at the root, `lib/` for implementation, `tests/` for tests);
- "import only through a package's entry points (its root files)", with any root file counting as an entry point;
- the four rules, one paragraph each;
- how to run the boundary check, plus anything **README** in the runtime file adds;
- the blind spot: imports built at runtime from a variable (`import(name)`) are invisible to the checker;
- **barrel files discouraged** explicitly: expose several small entry points instead of re-exporting a whole subtree through one entry file.

Keep it to the copy-me snippet plus those points. If step 1 found existing code outside the packages root, end the README with one line suggesting `/improve-codebase-architecture` to decide which existing folders should become packages.

Then add a **context pointer** to it from the repo's agent-instructions file (`CLAUDE.md` if present, else `AGENTS.md`, creating `AGENTS.md` if neither exists; if `CLAUDE.md` only imports `AGENTS.md`, write to `AGENTS.md`). One line is enough, e.g. `Packages are deep modules: see [src/packages/README.md](./src/packages/README.md) before adding or importing one.` This is what makes an agent discover the boundary rule instead of tripping over it.

**Done when:** `<packages-root>/README.md` exists and discourages barrels, and the repo's agent-instructions file links to it.

## Notes

- Public vs private is decided by **depth**: a package's root files are entry points; anything in a subfolder is private. The conventional subfolders are `lib/` and `tests/`, but the rule doesn't hardcode them: any subfolder is private, so a new folder never needs a config change. Adding an entry point is just adding a root file (no barrel).
- Packages are **flat**: one tier of immediate children under the root. A package's internals may nest as deep as you like; a package may not contain another package.
- Imports built at runtime from a variable (`import(name)`) are invisible to both checkers. Literal dynamic imports are checked like static ones.
