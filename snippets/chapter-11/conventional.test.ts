import { Miniflare } from "miniflare";
import { afterAll, expect, test } from "vitest";

// Each Worker built beforehand, and wired the way wrangler.toml wires it.
const mf = new Miniflare({
  workers: [
    {
      name: "shop-orders",
      modules: true,
      scriptPath: "dist/orders.js",
      bindings: { AUTH_JWT_SECRET: "test-secret" },
      durableObjects: { ORDER: "Order" },
      serviceBindings: {
        INVENTORY: "shop-inventory",
        PAYMENTS: "shop-payments",
      },
    },
    {
      name: "shop-inventory",
      modules: true,
      scriptPath: "dist/inventory.js",
      durableObjects: { INVENTORY: "Inventory" },
    },
    {
      name: "shop-payments",
      modules: true,
      scriptPath: "dist/payments.js",
      bindings: { PAYMENTS_PROCESSOR: "fake" },
    },
  ],
});
afterAll(() => mf.dispose());

declare function signToken(sub: string): Promise<string>;

test("a customer places an order across three Workers", async () => {
  const res = await mf.dispatchFetch("http://localhost/orders/o1", {
    method: "PUT",
    headers: { Authorization: `Bearer ${await signToken("alice")}` },
    body: JSON.stringify({ sku: "widget", qty: 3, cents: 2500 }),
  });
  expect(res.status).toBe(201);
});
