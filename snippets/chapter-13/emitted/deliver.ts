try {
  await __deliverEvent(binding, sub.service, ev.payload, ev.envelope, this.env, "shop.orders", sub.context);
} catch (e) {
