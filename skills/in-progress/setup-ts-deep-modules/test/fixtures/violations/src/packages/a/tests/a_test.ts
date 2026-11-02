import { greet } from "../mod.ts"; // entry point: allowed
import { name } from "./fixture.ts"; // own fixture: allowed
import { impl } from "../lib/impl.ts"; // tests-through-entrypoints
import { util } from "../../b/lib/util.ts"; // tests-through-entrypoints
console.log(greet(), name, impl(), util);
