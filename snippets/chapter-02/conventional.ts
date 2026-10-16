import { z } from "zod";

const Sku = z.string().min(1).brand<"Sku">();
const OrderId = z.string().min(1).brand<"OrderId">();
type Sku = z.infer<typeof Sku>;

const OrderLine = z.object({
  sku: Sku,
  qty: z.number().int().min(1).max(1000),
  cents: z.number().int().min(1).max(10_000_000),
});
type OrderLine = z.infer<typeof OrderLine>;

export default {
  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname;
    const found = path.match(/^\/orders\/([^/]+)$/);
    if (request.method !== "PUT" || !found) {
      return new Response("Not found", { status: 404 });
    }
    const id = OrderId.safeParse(found[1]);
    const line = OrderLine.safeParse(await request.json());
    if (!id.success || !line.success) {
      return Response.json({ error: "invalid order" }, { status: 400 });
    }
    return Response.json(line.data, { status: 201 });
  },
};
