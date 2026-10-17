try {
  await __deliverEvent(binding, sub.service, ev.payload, ev.envelope);
} catch (e) {
