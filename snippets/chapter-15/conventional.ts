const SCHEMA = 2;

export class Order extends DurableObject {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    // Before any request is served, bring stored data up to date.
    ctx.blockConcurrencyWhile(async () => {
      const version = (await ctx.storage.get<number>("schema")) ?? 1;
      if (version < 2) {
        // Version 1 stored the owner as a bare string; version 2 keeps
        // a record. Every reader of "owner" must change with this.
        const owner = await ctx.storage.get<string>("owner");
        if (owner !== undefined) {
          await ctx.storage.put("owner", { id: owner, since: null });
        }
      }
      await ctx.storage.put("schema", SCHEMA);
    });
  }
}
