} catch (e) {
  globalThis.console.error(`shop.orders ${__route} faulted`, e instanceof globalThis.Error ? (e.stack || globalThis.String(e)) : e);
  return new globalThis.Response("Internal Server Error", { status: 500 });
