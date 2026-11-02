import type { Greeting } from "../a/lib/impl.ts"; // type-only, entrypoint-boundary-across-packages
import { util } from "./lib/util.ts";
export const b: Greeting = util;
