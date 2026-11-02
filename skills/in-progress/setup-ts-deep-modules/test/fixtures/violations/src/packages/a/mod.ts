import { impl } from "./lib/impl.ts"; // intra-package: allowed
export const greet = (): string => impl();
