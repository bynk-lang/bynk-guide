// The shape both Workers agree on, written once in each.
type OrderEvent = {
  id: string;
  type: "OrderPlaced" | "OrderCancelled";
  orderId: string;
  qty: number;
  cents: number;
};

// In orders, once the order is placed:
await env.ORDER_EVENTS.send({
  id: crypto.randomUUID(),
  type: "OrderPlaced",
  orderId,
  qty,
  cents,
} satisfies OrderEvent);

// In the ledger, a queue consumer:
export default {
  async queue(batch: MessageBatch<OrderEvent>, env: Env) {
    for (const msg of batch.messages) {
      if (await env.SEEN.get(msg.body.id)) {
        msg.ack();
        continue;
      }
      const books = env.BOOKS.get(env.BOOKS.idFromName("main"));
      await books.fetch(`https://books/${msg.body.type}`, {
        method: "POST",
        body: JSON.stringify(msg.body),
      });
      await env.SEEN.put(msg.body.id, "1", { expirationTtl: 7 * 86400 });
      msg.ack();
    }
  },
};
