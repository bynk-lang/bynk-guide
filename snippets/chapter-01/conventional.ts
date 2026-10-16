export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/") {
      return Response.json("Hello from hello!");
    }

    const found = url.pathname.match(/^\/hello\/([^/]+)$/);
    if (request.method === "GET" && found) {
      const name = decodeURIComponent(found[1]);
      return Response.json(`Hello, ${name}!`);
    }
    return new Response("Not Found", { status: 404 });
  },
};
