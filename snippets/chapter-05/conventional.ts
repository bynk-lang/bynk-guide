import { DurableObject } from "cloudflare:workers";

type Hold = { order: string; qty: number };

export class Inventory extends DurableObject {
  async reserve(order: string, qty: number): Promise<boolean> {
    return this.ctx.storage.transaction(async (txn) => {
      if (await txn.get(`hold:${order}`)) return true;
      const available = (await txn.get<number>("available")) ?? 0;
      if (available < qty) return false;
      await txn.put("available", available - qty);
      await txn.put(`hold:${order}`, { order, qty });
      return true;
    });
  }

  async held(): Promise<number> {
    const holds = await this.ctx.storage.list<Hold>({ prefix: "hold:" });
    let total = 0;
    for (const hold of holds.values()) total += hold.qty;
    return total;
  }
}
