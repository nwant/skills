import { assertEquals } from "@std/assert";
import { greet } from "../src/greet.ts";

Deno.test("greet", () => {
  assertEquals(greet("deno"), "hello, deno");
});
