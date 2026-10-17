} catch (e) {
  globalThis.console.error(`shop.orders ${__route} faulted`, e);
  return new globalThis.Response("Internal Server Error", { status: 500 });
