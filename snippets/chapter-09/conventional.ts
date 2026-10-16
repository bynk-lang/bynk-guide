// processor.ts
export interface Env {
  PAYMENTS_PROCESSOR?: string;
}
export type Charge = { ok: true; id: string } | { ok: false; why: string };

export async function charge(env: Env, reference: string, cents: number) {
  if (env.PAYMENTS_PROCESSOR !== "fake") {
    return { ok: false, why: "unavailable" } satisfies Charge;
  }
  if (cents > 100000) {
    return { ok: false, why: "declined" } satisfies Charge;
  }
  return { ok: true, id: `fake_${reference}` } satisfies Charge;
}
