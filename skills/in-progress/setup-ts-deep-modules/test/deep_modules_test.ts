// Unit tests for the Deno deep-module checker. Each test writes a small repo
// into a temp dir and asserts which rules fire.
//
// Run from the skill folder:
//   deno test --allow-read --allow-write --allow-run=deno test/deep_modules_test.ts
import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "jsr:@std/assert@^1";
import { dirname, join } from "jsr:@std/path@^1";
import { check, format, parseGraph, type Violation } from "../deep_modules.ts";

type Tree = Record<string, string>;

async function repo(tree: Tree): Promise<string> {
  const root = await Deno.makeTempDir({ prefix: "deep_modules_" });
  for (const [path, body] of Object.entries(tree)) {
    await Deno.mkdir(join(root, dirname(path)), { recursive: true });
    await Deno.writeTextFile(join(root, path), body);
  }
  return root;
}

async function run(tree: Tree, layering: { from: string; to: string }[] = []) {
  const root = await repo(tree);
  try {
    return await check({
      root,
      packagesRoot: "src/packages",
      // Scan whichever of src/ and test/ the tree has; a missing one is an error.
      scanPaths: ["src", "test"].filter((dir) =>
        Object.keys(tree).some((path) => path.startsWith(`${dir}/`))
      ),
      layering,
    });
  } finally {
    await Deno.remove(root, { recursive: true });
  }
}

function edges(violations: Violation[]): string[] {
  return violations.map((v) => `${v.rule} ${v.from} -> ${v.to}`).sort();
}

const clean: Tree = {
  "src/app.ts":
    'import { greet } from "./packages/a/mod.ts";\nconsole.log(greet());\n',
  "src/packages/a/mod.ts":
    'import { impl } from "./lib/impl.ts";\nexport const greet = () => impl();\n',
  "src/packages/a/lib/impl.ts": 'export const impl = () => "hi";\n',
  "src/packages/a/tests/a_test.ts":
    'import { greet } from "../mod.ts";\nimport { name } from "./fixture.ts";\ngreet();\nname;\n',
  "src/packages/a/tests/fixture.ts": 'export const name = "x";\n',
};

Deno.test("a clean repo passes and counts its modules", async () => {
  const result = await run(clean);
  assertEquals(result.violations, []);
  assertEquals(result.modules, 5);
});

Deno.test("entrypoint-boundary-from-app: app code reaching into a package subfolder", async () => {
  const result = await run({
    ...clean,
    "src/app.ts": 'import { impl } from "./packages/a/lib/impl.ts";\nimpl();\n',
  });
  assertEquals(edges(result.violations), [
    "entrypoint-boundary-from-app src/app.ts -> src/packages/a/lib/impl.ts",
  ]);
  assertEquals([result.violations[0].line, result.violations[0].col], [1, 22]);
});

Deno.test("entrypoint-boundary-across-packages: one package reaching into another's internals", async () => {
  const result = await run({
    ...clean,
    "src/packages/b/mod.ts":
      'import { impl } from "../a/lib/impl.ts";\nexport const b = impl;\n',
  });
  assertEquals(edges(result.violations), [
    "entrypoint-boundary-across-packages src/packages/b/mod.ts -> src/packages/a/lib/impl.ts",
  ]);
});

Deno.test("a package's own files import each other freely, including internal → entry point", async () => {
  const result = await run({
    ...clean,
    "src/packages/a/lib/more.ts":
      'import { impl } from "./impl.ts";\nexport const more = impl;\n',
    "src/packages/b/mod.ts":
      'import { greet } from "../a/mod.ts";\nexport const b = greet;\n',
  });
  assertEquals(result.violations, []);
});

Deno.test("tests-through-entrypoints: a test importing its own package's internals", async () => {
  const result = await run({
    ...clean,
    "src/packages/a/tests/a_test.ts":
      'import { impl } from "../lib/impl.ts";\nimpl();\n',
  });
  assertEquals(edges(result.violations), [
    "tests-through-entrypoints src/packages/a/tests/a_test.ts -> src/packages/a/lib/impl.ts",
  ]);
});

Deno.test("tests-folder-is-private: non-test code importing a fixture", async () => {
  const result = await run({
    ...clean,
    "src/packages/a/mod.ts":
      'import { name } from "./tests/fixture.ts";\nexport const greet = () => name;\n',
  });
  assertEquals(edges(result.violations), [
    "tests-folder-is-private src/packages/a/mod.ts -> src/packages/a/tests/fixture.ts",
  ]);
});

Deno.test("no-circular: one report per cycle, with its full path", async () => {
  const result = await run({
    "src/x.ts": 'import { y } from "./y.ts";\nexport const x = () => y;\n',
    "src/y.ts": 'import { z } from "./z.ts";\nexport const y = () => z;\n',
    "src/z.ts": 'import { x } from "./x.ts";\nexport const z = () => x;\n',
  });
  assertEquals(edges(result.violations), ["no-circular src/x.ts -> src/y.ts"]);
  assertEquals(result.violations[0].cycle, [
    "src/x.ts",
    "src/y.ts",
    "src/z.ts",
    "src/x.ts",
  ]);
});

Deno.test("no-circular: a module importing itself is a cycle", async () => {
  const result = await run({
    "src/x.ts":
      'import * as self from "./x.ts";\nexport const x = () => self;\n',
  });
  assertEquals(edges(result.violations), ["no-circular src/x.ts -> src/x.ts"]);
  assertEquals(result.violations[0].cycle, ["src/x.ts", "src/x.ts"]);
});

Deno.test("type-only imports count: a deep `import type` is a violation", async () => {
  const result = await run({
    ...clean,
    "src/packages/a/lib/impl.ts":
      'export type T = number;\nexport const impl = () => "hi";\n',
    "src/packages/b/mod.ts":
      'import type { T } from "../a/lib/impl.ts";\nexport const b: T = 1;\n',
  });
  assertEquals(edges(result.violations), [
    "entrypoint-boundary-across-packages src/packages/b/mod.ts -> src/packages/a/lib/impl.ts",
  ]);
});

Deno.test("import-map aliases resolve: a deep import through an alias is still caught", async () => {
  const result = await run({
    ...clean,
    "deno.json": JSON.stringify({ imports: { "#/": "./src/" } }),
    "src/app.ts": 'import { impl } from "#/packages/a/lib/impl.ts";\nimpl();\n',
  });
  assertEquals(edges(result.violations), [
    "entrypoint-boundary-from-app src/app.ts -> src/packages/a/lib/impl.ts",
  ]);
});

Deno.test("files nobody imports are still checked", async () => {
  const result = await run({
    ...clean,
    "test/orphan_test.ts":
      'import { impl } from "../src/packages/a/lib/impl.ts";\nimpl();\n',
  });
  assertEquals(edges(result.violations), [
    "entrypoint-boundary-from-app test/orphan_test.ts -> src/packages/a/lib/impl.ts",
  ]);
});

Deno.test("layering: a forbidden package pair fails even through the entry point", async () => {
  const result = await run(
    {
      ...clean,
      "src/packages/b/mod.ts":
        'import { greet } from "../a/mod.ts";\nexport const b = greet;\n',
    },
    [{ from: "b", to: "a" }],
  );
  assertEquals(edges(result.violations), [
    "layering-b-may-not-depend-on-a src/packages/b/mod.ts -> src/packages/a/mod.ts",
  ]);
});

Deno.test("a missing scan path is an error, not a silent skip", async () => {
  const root = await repo(clean);
  try {
    await assertRejects(
      () =>
        check({
          root,
          packagesRoot: "src/packages",
          scanPaths: ["src", "tset"],
          layering: [],
        }),
      Error,
      'scan path "tset" does not exist',
    );
  } finally {
    await Deno.remove(root, { recursive: true });
  }
});

Deno.test("scan paths normalize: '.', './src' and 'src/' all work", async () => {
  const root = await repo(clean);
  try {
    for (const scanPaths of [["."], ["./src"], ["src/"]]) {
      const result = await check({
        root,
        packagesRoot: "src/packages",
        scanPaths,
        layering: [],
      });
      assertEquals(result.violations, [], scanPaths.join());
      assertEquals(result.modules, 5, scanPaths.join());
    }
  } finally {
    await Deno.remove(root, { recursive: true });
  }
});

Deno.test("zero local modules is an error, not a pass", async () => {
  await assertRejects(
    () => run({ "src/README.md": "no code\n", "test/README.md": "no code\n" }),
    Error,
    "found no modules",
  );
});

Deno.test("an unknown deno info graph version is an error, not an empty graph", () => {
  let message = "";
  try {
    parseGraph(JSON.stringify({ version: 99, roots: [], modules: [] }));
  } catch (e) {
    message = (e as Error).message;
  }
  assertStringIncludes(message, "unsupported deno info --json version 99");
});

Deno.test("format prints rule, location, target and the cycle path", () => {
  const out = format({
    modules: 2,
    violations: [{
      rule: "no-circular",
      from: "src/x.ts",
      to: "src/y.ts",
      line: 1,
      col: 19,
      cycle: ["src/x.ts", "src/y.ts", "src/x.ts"],
    }],
  });
  assertStringIncludes(out, "error no-circular: src/x.ts:1:19 → src/y.ts");
  assertStringIncludes(out, "cycle: src/x.ts → src/y.ts → src/x.ts");
  assertStringIncludes(out, "1 violation (2 modules checked)");
});
