// Deep-module enforcement for Deno repos. Zero dependencies.
//
// Each package under PACKAGES_ROOT is a DEEP MODULE: a lot of behaviour behind
// a small interface. A package's PUBLIC SURFACE is its ENTRY POINTS: the files
// at the package root (mod.ts, client.ts, …). Implementation lives in
// SUBFOLDERS and is private (by convention `lib/` for implementation and
// `tests/` for tests, though any subfolder is private). Prefer several small
// entry points over one barrel that re-exports a whole subtree.
//
// The import graph comes from `deno info --json`, so imports resolve exactly
// as Deno resolves them: the deno.json import map, `.ts` extensions, and
// type-only imports all count. Only modules inside this repo are checked;
// jsr:, npm: and https: modules are ignored.
//
// Run with: deno run --allow-read=. --allow-run=deno tools/deep_modules.ts
// Exit 0: clean. Exit 1: violations. Exit 2: the checker could not run.
//
// The three constants below are the only things you should need to edit.

/** Where packages live. One immediate child dir per package (flat, no nesting). */
const PACKAGES_ROOT = "src/packages";

/** Directories to scan, relative to the repo root. Match what `deno check` gets. */
const SCAN_PATHS = ["src", "test"];

/**
 * Layering: which packages may not depend on which, by package name. Off by
 * default. Interface-hiding (the rules below) controls HOW you import; this
 * controls WHICH packages may import which, even through an entry point.
 * Example: [{ from: "ui", to: "billing" }]
 */
const LAYERING: { from: string; to: string }[] = [];

// --- no need to edit below ----------------------------------------------------

/** One import: `from` imports `to` at line:col (1-based). Paths are repo-relative. */
interface Edge {
  from: string;
  to: string;
  line: number;
  col: number;
}

export interface Violation {
  rule: string;
  from: string;
  to: string;
  line: number;
  col: number;
  cycle?: string[];
}

export interface Result {
  modules: number;
  violations: Violation[];
}

export interface Options {
  root: string;
  packagesRoot: string;
  scanPaths: string[];
  layering: { from: string; to: string }[];
}

interface Span {
  start: { line: number; character: number };
}
interface Resolved {
  specifier?: string;
  span?: Span;
  error?: string;
}
interface Dependency {
  specifier: string;
  code?: Resolved;
  type?: Resolved;
}
interface Module {
  specifier: string;
  local?: string;
  error?: string;
  dependencies?: Dependency[];
}
interface Graph {
  version: number;
  modules: Module[];
}

/** The `deno info --json` graph versions this checker understands. */
const SUPPORTED_GRAPH_VERSIONS = [1];

const SOURCE_EXTENSIONS = [".ts", ".tsx", ".mts", ".js", ".jsx", ".mjs"];

/** Parse `deno info --json` output, refusing a graph shape it doesn't know. */
export function parseGraph(json: string): Graph {
  const graph = JSON.parse(json) as Graph;
  if (!SUPPORTED_GRAPH_VERSIONS.includes(graph.version)) {
    throw new Error(
      `unsupported deno info --json version ${graph.version} ` +
        `(this checker knows ${
          SUPPORTED_GRAPH_VERSIONS.join(", ")
        }); update tools/deep_modules.ts`,
    );
  }
  return graph;
}

async function denoInfo(root: string, file: string): Promise<Graph> {
  let output: Deno.CommandOutput;
  try {
    output = await new Deno.Command("deno", {
      args: ["info", "--json", file],
      cwd: root,
      stdout: "piped",
      stderr: "piped",
    }).output();
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) {
      throw new Error("`deno` not found on PATH");
    }
    throw e;
  }
  if (!output.success) {
    throw new Error(
      `deno info failed for ${file}:\n${
        new TextDecoder().decode(output.stderr)
      }`,
    );
  }
  return parseGraph(new TextDecoder().decode(output.stdout));
}

async function* sourceFiles(dir: string): AsyncGenerator<string> {
  for await (const entry of Deno.readDir(dir)) {
    if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
    const path = `${dir}/${entry.name}`;
    if (entry.isDirectory) yield* sourceFiles(path);
    else if (
      entry.isFile &&
      SOURCE_EXTENSIONS.some((ext) => entry.name.endsWith(ext))
    ) yield path;
  }
}

/** Absolute path of a scan entry; `.`, `./src` and `src/` all normalize. */
function scanRoot(root: string, scan: string): string {
  const trimmed = scan.replace(/^(\.\/)+/, "").replace(/\/+$/, "");
  return trimmed === "" || trimmed === "." ? root : `${root}/${trimmed}`;
}

/** Every source file under one scan entry. A missing entry is an error, not an empty scan. */
async function* scanFiles(root: string, scan: string): AsyncGenerator<string> {
  const path = scanRoot(root, scan);
  let info: Deno.FileInfo;
  try {
    info = await Deno.stat(path);
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) {
      throw new Error(
        `scan path "${scan}" does not exist; check SCAN_PATHS in tools/deep_modules.ts`,
      );
    }
    throw e;
  }
  if (info.isFile) yield path;
  else yield* sourceFiles(path);
}

/** Where a repo-relative path sits relative to the packages root. */
function classify(path: string, packagesRoot: string) {
  const prefix = `${packagesRoot}/`;
  if (!path.startsWith(prefix)) {
    return { inside: false, pkg: undefined, internal: false, test: false };
  }
  const parts = path.slice(prefix.length).split("/");
  return {
    inside: true,
    // A file directly in the packages root belongs to no package.
    pkg: parts.length >= 2 ? parts[0] : undefined,
    // Anything nested inside a package subfolder is private.
    internal: parts.length >= 3,
    test: parts.length >= 3 && parts[1] === "tests",
  };
}

/** The interface-hiding rules, the same five as the dependency-cruiser config. */
function boundaryRules(
  from: string,
  to: string,
  packagesRoot: string,
  layering: { from: string; to: string }[],
): string[] {
  const f = classify(from, packagesRoot);
  const t = classify(to, packagesRoot);
  const rules: string[] = [];
  // App code may import a package's entry points, never its subfolders.
  if (!f.inside && t.internal) rules.push("entrypoint-boundary-from-app");
  // A package reaches OTHER packages only through their entry points.
  if (f.pkg !== undefined && !f.test && t.internal && t.pkg !== f.pkg) {
    rules.push("entrypoint-boundary-across-packages");
  }
  // Tests go through entry points too: only their own tests/ fixtures are exempt.
  if (f.test && t.internal && !(t.pkg === f.pkg && t.test)) {
    rules.push("tests-through-entrypoints");
  }
  // Only tests may import a tests/ folder.
  if (!f.test && t.test) rules.push("tests-folder-is-private");
  for (const layer of layering) {
    if (f.pkg === layer.from && t.pkg === layer.to) {
      rules.push(`layering-${layer.from}-may-not-depend-on-${layer.to}`);
    }
  }
  return rules;
}

/** Strongly connected components (Tarjan). Two modules share one iff each reaches the other. */
function components(
  nodes: string[],
  out: Map<string, Set<string>>,
): Map<string, number> {
  const index = new Map<string, number>();
  const low = new Map<string, number>();
  const onStack = new Set<string>();
  const stack: string[] = [];
  const component = new Map<string, number>();
  let counter = 0;
  let next = 0;
  const visit = (v: string) => {
    index.set(v, counter);
    low.set(v, counter);
    counter++;
    stack.push(v);
    onStack.add(v);
    for (const w of out.get(v) ?? []) {
      if (!index.has(w)) {
        visit(w);
        low.set(v, Math.min(low.get(v)!, low.get(w)!));
      } else if (onStack.has(w)) {
        low.set(v, Math.min(low.get(v)!, index.get(w)!));
      }
    }
    if (low.get(v) === index.get(v)) {
      let w: string;
      do {
        w = stack.pop()!;
        onStack.delete(w);
        component.set(w, next);
      } while (w !== v);
      next++;
    }
  };
  for (const v of nodes) if (!index.has(v)) visit(v);
  return component;
}

/** Shortest path from `start` to `goal`, staying inside one component. */
function pathWithin(
  start: string,
  goal: string,
  out: Map<string, Set<string>>,
  component: Map<string, number>,
): string[] {
  const previous = new Map<string, string | undefined>([[start, undefined]]);
  const queue = [start];
  while (queue.length > 0) {
    const v = queue.shift()!;
    if (v === goal) break;
    for (const w of out.get(v) ?? []) {
      if (!previous.has(w) && component.get(w) === component.get(start)) {
        previous.set(w, v);
        queue.push(w);
      }
    }
  }
  const path: string[] = [];
  for (let v: string | undefined = goal; v !== undefined; v = previous.get(v)) {
    path.unshift(v);
  }
  return path;
}

/** Build the repo's local import graph and report every rule violation. */
export async function check(options: Options): Promise<Result> {
  const root = await Deno.realPath(options.root);
  const relative = (local: string) =>
    local.startsWith(`${root}/`) ? local.slice(root.length + 1) : undefined;

  const edges = new Map<string, Edge>();
  const nodes = new Set<string>();
  const seen = new Set<string>();

  for (const scan of options.scanPaths) {
    for await (const file of scanFiles(root, scan)) {
      if (seen.has(file)) continue;
      const graph = await denoInfo(root, file);
      for (const module of graph.modules) {
        if (module.error || !module.local) continue;
        const from = relative(module.local);
        if (from === undefined) continue;
        seen.add(module.local);
        nodes.add(from);
        for (const dependency of module.dependencies ?? []) {
          // A dependency can resolve twice (code and @ts-types); both are edges.
          for (const resolved of [dependency.code, dependency.type]) {
            if (!resolved?.specifier?.startsWith("file://") || resolved.error) {
              continue;
            }
            const to = relative(
              decodeURIComponent(new URL(resolved.specifier).pathname),
            );
            if (to === undefined) continue;
            const key = `${from}\0${to}`;
            if (edges.has(key)) continue;
            edges.set(key, {
              from,
              to,
              line: (resolved.span?.start.line ?? 0) + 1,
              col: (resolved.span?.start.character ?? 0) + 1,
            });
          }
        }
      }
    }
  }

  if (nodes.size === 0) {
    throw new Error(
      `found no modules under ${
        options.scanPaths.join(", ")
      }; check SCAN_PATHS in tools/deep_modules.ts`,
    );
  }

  const out = new Map<string, Set<string>>();
  for (const { from, to } of edges.values()) {
    if (!out.has(from)) out.set(from, new Set());
    out.get(from)!.add(to);
  }
  const component = components([...nodes].sort(), out);

  const violations: Violation[] = [];
  // One no-circular report per cycle, anchored at its first edge in path
  // order, as dependency-cruiser does: a five-file cycle is one error, not five.
  const cycleAnchor = new Map<number, Edge>();
  for (const edge of edges.values()) {
    for (
      const rule of boundaryRules(
        edge.from,
        edge.to,
        options.packagesRoot,
        options.layering,
      )
    ) {
      violations.push({ rule, ...edge });
    }
    // An edge is in a cycle iff both ends share a component (or it is a self-import).
    const id = component.get(edge.from)!;
    if (edge.from === edge.to || id === component.get(edge.to)) {
      const anchor = cycleAnchor.get(id);
      if (
        !anchor || edge.from < anchor.from ||
        (edge.from === anchor.from && edge.to < anchor.to)
      ) cycleAnchor.set(id, edge);
    }
  }
  for (const edge of cycleAnchor.values()) {
    const cycle = [
      edge.from,
      ...pathWithin(edge.to, edge.from, out, component),
    ];
    violations.push({ rule: "no-circular", ...edge, cycle });
  }
  violations.sort((a, b) =>
    a.from.localeCompare(b.from) || a.line - b.line || a.col - b.col ||
    a.rule.localeCompare(b.rule)
  );
  return { modules: nodes.size, violations };
}

/** Human-readable report, in the same shape as dependency-cruiser's. */
export function format(result: Result): string {
  const checked = `(${result.modules} modules checked)`;
  if (result.violations.length === 0) {
    return `✔ no deep-module violations ${checked}`;
  }
  const lines = result.violations.map((v) => {
    const head = `  error ${v.rule}: ${v.from}:${v.line}:${v.col} → ${v.to}`;
    return v.cycle ? `${head}\n      cycle: ${v.cycle.join(" → ")}` : head;
  });
  const n = result.violations.length;
  return `${lines.join("\n")}\n\nx ${n} violation${
    n === 1 ? "" : "s"
  } ${checked}`;
}

if (import.meta.main) {
  try {
    const result = await check({
      root: Deno.cwd(),
      packagesRoot: PACKAGES_ROOT,
      scanPaths: SCAN_PATHS,
      layering: LAYERING,
    });
    console.log(format(result));
    Deno.exit(result.violations.length > 0 ? 1 : 0);
  } catch (e) {
    console.error(
      `deep_modules: ${e instanceof Error ? e.message : String(e)}`,
    );
    Deno.exit(2);
  }
}
