// App code: one legal import, two deep ones.
import { greet } from "./packages/a/mod.ts";
import { impl } from "./packages/a/lib/impl.ts"; // entrypoint-boundary-from-app
import { name } from "./packages/a/tests/fixture.ts"; // from-app + tests-folder-is-private
console.log(greet(), impl(), name);
