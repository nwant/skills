import { c } from "../mod.ts"; // no-circular
export const x = (): number => (typeof c === "function" ? 1 : 0);
