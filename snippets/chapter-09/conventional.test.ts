// authorise.test.ts
import { expect, test, vi } from "vitest";
import { charge } from "./processor";
import { authorise } from "./authorise";

vi.mock("./processor", () => ({
  charge: vi.fn(async () => ({ ok: true, id: "auth_1" })),
}));

test("authorise hands the order id to the processor", async () => {
  const env = { PAYMENTS_PROCESSOR: "fake" };
  const r = await authorise(env, "o2", 2500);
  expect(r).toEqual({ ok: true, id: "auth_1" });
  expect(charge).toHaveBeenCalledWith(env, "o2", 2500);
});
