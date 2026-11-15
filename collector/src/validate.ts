import { z } from "zod";

export const MAX_EVENTS = 50;

const text = (max: number) => z.string().max(max, `longer than ${max} characters`).refine((s) => !s.includes("\u0000"), "contains NUL");
const scalar = z.union([text(200), z.number(), z.boolean()], { error: "must be a string, number or boolean" });

const params = z
  .record(z.string(), scalar)
  .refine((o) => Object.keys(o).length <= 20, "more than 20 keys")
  .refine((o) => Object.keys(o).every((k) => k.length >= 1 && k.length <= 64 && !k.includes("\u0000")), "bad key");

const EventSchema = z.object({
  name: z.string({ error: "required" }).regex(/^[a-z][a-z0-9_]{0,63}$/, "must match ^[a-z][a-z0-9_]{0,63}$"),
  params: params.nullish(),
  path: z.string().max(500).regex(/^\/[^?#\u0000]*$/, "must start with / and have no ? or #").nullish(),
  referrer: text(2000).nullish(),
  utm: z.object({ source: text(100).nullish(), medium: text(100).nullish(), campaign: text(100).nullish() }).nullish(),
  language: text(35).nullish(),
});

export interface CleanEvent {
  name: string;
  params: Record<string, string | number | boolean>;
  path: string | null;
  referrerHost: string | null;
  utmSource: string | null;
  utmMedium: string | null;
  utmCampaign: string | null;
  language: string | null;
}

export type EventResult = { ok: true; event: CleanEvent } | { ok: false; reason: string };

/** The host of an http(s) referrer URL, lower-case, or null when absent or not a URL. */
function hostOf(referrer: string | null | undefined): string | null {
  if (!referrer) return null;
  try {
    const u = new URL(referrer);
    return u.protocol === "http:" || u.protocol === "https:" ? u.hostname.toLowerCase() : null;
  } catch {
    return null;
  }
}

export function validateEvent(raw: unknown): EventResult {
  const r = EventSchema.safeParse(raw);
  if (!r.success) {
    const i = r.error.issues[0];
    const where = i?.path.join(".") || "event";
    return { ok: false, reason: `${where}: ${i?.message ?? "invalid"}` };
  }
  const e = r.data;
  return {
    ok: true,
    event: {
      name: e.name,
      params: e.params ?? {},
      path: e.path ?? null,
      referrerHost: hostOf(e.referrer),
      utmSource: e.utm?.source?.toLowerCase() || null,
      utmMedium: e.utm?.medium || null,
      utmCampaign: e.utm?.campaign || null,
      language: e.language || null,
    },
  };
}

export type BatchResult = { ok: true; source: string; events: unknown[] } | { ok: false; error: string };

/** Checks the envelope only; each event is checked on its own by validateEvent. */
export function validateBatch(body: unknown): BatchResult {
  if (typeof body !== "object" || body === null || Array.isArray(body)) return { ok: false, error: "body must be a JSON object" };
  const { source, events } = body as Record<string, unknown>;
  if (typeof source !== "string" || !/^[a-z0-9][a-z0-9_-]{0,63}$/i.test(source)) return { ok: false, error: "source is missing or malformed" };
  if (!Array.isArray(events) || events.length === 0) return { ok: false, error: "events must be a non-empty array" };
  if (events.length > MAX_EVENTS) return { ok: false, error: `more than ${MAX_EVENTS} events` };
  return { ok: true, source, events };
}
