const encoder = new TextEncoder();

// Verify a processor's webhook: an HMAC-SHA256 of "<timestamp>.<body>",
// sent as "sha256=<hex>", with the timestamp at most five minutes off.
export async function verified(request: Request, secret: string) {
  const ts = request.headers.get("X-Processor-Timestamp");
  const sig = request.headers.get("X-Processor-Signature") ?? "";
  if (ts === null || !/^\d+$/.test(ts)) return null;
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return null;

  const body = await request.text(); // the raw body, read exactly once
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${ts}.${body}`),
  );
  const hex = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  // Compare in constant time, or the comparison leaks the signature.
  const want = encoder.encode(`sha256=${hex}`);
  const got = encoder.encode(sig);
  if (want.length !== got.length) return null;
  let diff = 0;
  for (let i = 0; i < want.length; i++) diff |= want[i] ^ got[i];
  return diff === 0 ? body : null;
}
