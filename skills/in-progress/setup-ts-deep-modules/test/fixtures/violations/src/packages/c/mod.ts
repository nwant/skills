import { x } from "./lib/x.ts"; // no-circular (with x.ts → mod.ts)
export const c = (): number => x();
