import { jwtVerify } from "jose";

interface Env {
  AUTH_JWT_SECRET: string;
}
type Caller = { sub: string; admin: boolean };

async function verify(request: Request, env: Env): Promise<Caller | null> {
  const header = request.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) return null;
  try {
    const key = new TextEncoder().encode(env.AUTH_JWT_SECRET);
    const { payload } = await jwtVerify(header.slice(7), key);
    if (typeof payload.sub !== "string" || payload.sub === "") return null;
    return { sub: payload.sub, admin: payload.admin === true };
  } catch {
    return null;
  }
}

// Every route that needs a caller starts the same way.
export async function restock(request: Request, env: Env) {
  const caller = await verify(request, env);
  if (caller === null) return new Response(null, { status: 401 });
  if (!caller.admin) return new Response(null, { status: 403 });
  // ... restock, as before
  return Response.json(10);
}
