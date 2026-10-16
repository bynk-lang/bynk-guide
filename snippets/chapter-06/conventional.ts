import { DurableObject } from "cloudflare:workers";

type Status = "pending" | "opened" | "placed" | "rejected" | "cancelled";

export class Order extends DurableObject {
  private async status(): Promise<Status> {
    return (await this.ctx.storage.get<Status>("status")) ?? "pending";
  }

  async confirm(): Promise<void> {
    await this.ctx.storage.put("status", "placed");
  }

  async reject(): Promise<void> {
    await this.ctx.storage.put("status", "rejected");
  }

  async cancel(): Promise<boolean> {
    if ((await this.status()) !== "placed") return false;
    await this.ctx.storage.put("status", "cancelled");
    return true;
  }
}
