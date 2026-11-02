// Parity check: the Node path (dependency-cruiser + the shipped .cjs config)
// and the Deno path (deep_modules.ts) must report the same violations on the
// same source tree, and both must match the expected list below.
//
// Needs Node and npm on PATH (it installs dependency-cruiser into a temp dir).
// Run from the skill folder:
//   deno run --allow-read --allow-write --allow-run test/parity.ts
import { assertEquals } from "jsr:@std/assert@^1";
import { copy } from "jsr:@std/fs@^1/copy";
import { fromFileUrl, join } from "jsr:@std/path@^1";
import { check } from "../deep_modules.ts";

const skill = fromFileUrl(new URL("..", import.meta.url));
const source = join(skill, "test/fixtures/violations/src");
const P = "src/packages";

// Every rule fires at least once; each line is `rule from -> to`.
const expected = [
  `entrypoint-boundary-across-packages ${P}/b/lib/util.ts -> ${P}/a/tests/fixture.ts`,
  `entrypoint-boundary-across-packages ${P}/b/mod.ts -> ${P}/a/lib/impl.ts`,
  `entrypoint-boundary-from-app src/app.ts -> ${P}/a/lib/impl.ts`,
  `entrypoint-boundary-from-app src/app.ts -> ${P}/a/tests/fixture.ts`,
  // Cycles compare as their sorted module set: the two tools may anchor the
  // report on different edges of the same cycle.
  `no-circular ${P}/c/lib/x.ts ${P}/c/mod.ts`,
  `tests-folder-is-private ${P}/b/lib/util.ts -> ${P}/a/tests/fixture.ts`,
  `tests-folder-is-private src/app.ts -> ${P}/a/tests/fixture.ts`,
  `tests-through-entrypoints ${P}/a/tests/a_test.ts -> ${P}/a/lib/impl.ts`,
  `tests-through-entrypoints ${P}/a/tests/a_test.ts -> ${P}/b/lib/util.ts`,
].sort();

function cycleKey(modules: string[]): string {
  return `no-circular ${[...new Set(modules)].sort().join(" ")}`;
}

async function sh(cwd: string, cmd: string, args: string[]): Promise<string> {
  const out = await new Deno.Command(cmd, {
    args,
    cwd,
    stdout: "piped",
    stderr: "piped",
  })
    .output();
  const stdout = new TextDecoder().decode(out.stdout);
  // depcruise exits non-zero when it finds violations, which is the point here.
  if (!out.success && stdout.trim() === "") {
    throw new Error(
      `${cmd} ${args.join(" ")} failed:\n${
        new TextDecoder().decode(out.stderr)
      }`,
    );
  }
  return stdout;
}

async function nodeViolations(): Promise<string[]> {
  const dir = await Deno.makeTempDir({ prefix: "parity_node_" });
  await copy(source, join(dir, "src"));
  await Deno.copyFile(
    join(skill, "dependency-cruiser.config.cjs"),
    join(dir, ".dependency-cruiser.cjs"),
  );
  await Deno.writeTextFile(
    join(dir, "package.json"),
    '{ "name": "parity", "private": true }',
  );
  await Deno.writeTextFile(
    join(dir, "tsconfig.json"),
    JSON.stringify({
      compilerOptions: {
        module: "esnext",
        moduleResolution: "bundler",
        allowImportingTsExtensions: true,
        noEmit: true,
      },
    }),
  );
  // dependency-cruiser 16 parses .ts only with TypeScript < 6.
  await sh(dir, "npm", [
    "install",
    "--silent",
    "-D",
    "dependency-cruiser@16",
    "typescript@5",
  ]);
  const json = JSON.parse(
    await sh(dir, "npx", ["depcruise", "src", "--output-type", "json"]),
  );
  if (json.summary.totalCruised === 0) {
    throw new Error("dependency-cruiser cruised 0 modules");
  }
  await Deno.remove(dir, { recursive: true });
  return json.summary.violations
    .map((
      v: {
        rule: { name: string };
        from: string;
        to: string;
        cycle?: { name: string }[];
      },
    ) =>
      v.cycle
        ? cycleKey(v.cycle.map((m) => m.name))
        : `${v.rule.name} ${v.from} -> ${v.to}`
    )
    .sort();
}

async function denoViolations(): Promise<string[]> {
  const dir = await Deno.makeTempDir({ prefix: "parity_deno_" });
  await copy(source, join(dir, "src"));
  await Deno.writeTextFile(join(dir, "deno.json"), "{}");
  const result = await check({
    root: dir,
    packagesRoot: P,
    scanPaths: ["src"],
    layering: [],
  });
  await Deno.remove(dir, { recursive: true });
  return result.violations
    .map((v) => v.cycle ? cycleKey(v.cycle) : `${v.rule} ${v.from} -> ${v.to}`)
    .sort();
}

const [node, deno] = await Promise.all([nodeViolations(), denoViolations()]);
assertEquals(deno, expected, "Deno checker differs from the expected list");
assertEquals(
  node,
  expected,
  "dependency-cruiser differs from the expected list",
);
console.log(
  `✔ parity: both paths report the same ${expected.length} violations`,
);
