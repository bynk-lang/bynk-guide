type OrderLine = { sku: string; qty: number; cents: number };

// The inventory and payments Workers each export a WorkerEntrypoint.
// These interfaces are copies of their shapes, kept in step by hand.
interface Inventory {
  reserve(sku: string, order: string, qty: number): Promise<boolean>;
  release(sku: string, order: string): Promise<number>;
}
interface Payments {
  authorise(order: string, cents: number): Promise<string | null>;
}
interface Env {
  INVENTORY: Inventory;
  PAYMENTS: Payments;
}

export async function place(env: Env, id: string, line: OrderLine) {
  if (!(await env.INVENTORY.reserve(line.sku, id, line.qty))) {
    return Response.json({ error: "out of stock" }, { status: 409 });
  }
  const auth = await env.PAYMENTS.authorise(id, line.cents);
  if (auth === null) {
    await env.INVENTORY.release(line.sku, id);
    return Response.json({ error: "payment declined" }, { status: 422 });
  }
  return Response.json(line, { status: 201 });
}
