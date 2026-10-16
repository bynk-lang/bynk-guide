import { DurableObject } from "cloudflare:workers";

type OrderLine = { sku: string; qty: number; cents: number };
interface Env {
  ORDER: DurableObjectNamespace<Order>;
}

export class Order extends DurableObject<Env> {
  async open(line: OrderLine): Promise<boolean> {
    const existing = await this.ctx.storage.get<OrderLine>("line");
    if (existing !== undefined) return false;
    await this.ctx.storage.put("line", line);
    return true;
  }

  async view(): Promise<OrderLine | undefined> {
    return this.ctx.storage.get<OrderLine>("line");
  }
}

// In the Worker's fetch handler, after the checks from chapter 3:
export async function place(env: Env, id: string, line: OrderLine) {
  const order = env.ORDER.get(env.ORDER.idFromName(id));
  if (!(await order.open(line))) {
    return new Response("that order has already been placed", {
      status: 409,
    });
  }
  return Response.json(line, { status: 201 });
}
