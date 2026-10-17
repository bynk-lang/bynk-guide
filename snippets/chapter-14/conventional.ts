// wrangler.toml, beside the code:
//   [triggers]
//   crons = ["*/5 * * * *"]

const HOLD_FOR_MS = 15 * 60 * 1000;

export default {
  async scheduled(event: ScheduledController, env: Env) {
    const cutoff = event.scheduledTime - HOLD_FOR_MS;
    const catalogue = env.CATALOGUE.get(env.CATALOGUE.idFromName("all"));
    const skus: string[] = await (
      await catalogue.fetch("https://do/skus")
    ).json();
    for (const sku of skus) {
      const stock = env.INVENTORY.get(env.INVENTORY.idFromName(sku));
      await stock.fetch("https://do/release-stale", {
        method: "POST",
        body: JSON.stringify({ cutoff }),
      });
    }
  },
};
