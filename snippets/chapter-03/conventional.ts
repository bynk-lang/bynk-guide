type OrderLine = { sku: string; qty: number; cents: number };
declare function parseLine(body: unknown): OrderLine; // chapter 2
declare function log(message: string): Promise<void>;

class OrderTooLarge extends Error {}

function total(line: OrderLine): number {
  const sum = line.qty * line.cents;
  if (sum > 10_000_000) {
    throw new OrderTooLarge("the order comes to more than 100,000.00");
  }
  return sum;
}

export default {
  async fetch(
    request: Request,
    env: unknown,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const line = parseLine(await request.json());
    try {
      const sum = total(line);
      ctx.waitUntil(log(`order for ${sum} cents`));
      return Response.json(line, { status: 201 });
    } catch (e) {
      if (e instanceof OrderTooLarge) {
        return Response.json({ error: e.message }, { status: 422 });
      }
      throw e;
    }
  },
};
