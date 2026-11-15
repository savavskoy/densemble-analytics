import http from "node:http";
import { detectNetwork, isCrawler } from "./network.js";
import { sessionKey, utcDay } from "./session.js";
import { validateBatch, validateEvent } from "./validate.js";
import type { Row, Store } from "./db.js";

export const MAX_BODY = 32 * 1024;

export interface Options {
  store: Store;
  secret: string;
  /** Allowed sources; null accepts any. */
  sources: ReadonlySet<string> | null;
  trustProxy: boolean;
  /** Receives short operational messages only: never addresses, user agents or event data. */
  log: (message: string) => void;
}

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "POST, OPTIONS",
  "access-control-allow-headers": "content-type",
  "access-control-max-age": "86400",
};

function send(res: http.ServerResponse, status: number, body?: unknown): void {
  const text = body === undefined ? "" : JSON.stringify(body);
  res.writeHead(status, { ...CORS, "content-type": "application/json", "content-length": Buffer.byteLength(text) });
  res.end(text);
}

/** Reads the body up to MAX_BODY bytes; resolves null when it is larger. */
function readBody(req: http.IncomingMessage): Promise<string | null> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    let size = 0;
    req.on("data", (c: Buffer) => {
      size += c.length;
      if (size > MAX_BODY) {
        chunks.length = 0;
        resolve(null);
        req.resume();
      } else chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function address(req: http.IncomingMessage, trustProxy: boolean): string {
  const fwd = req.headers["x-forwarded-for"];
  const first = (Array.isArray(fwd) ? fwd[0] : fwd)?.split(",")[0]?.trim();
  return trustProxy && first ? first : (req.socket.remoteAddress ?? "");
}

function originHost(origin: string | undefined): string | null {
  try {
    return origin ? new URL(origin).hostname.toLowerCase() : null;
  } catch {
    return null;
  }
}

async function handle(o: Options, req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
  const url = (req.url ?? "").split("?")[0];
  if (req.method === "OPTIONS") return send(res, 204);
  if (url === "/healthz" && req.method === "GET") {
    try {
      await o.store.ping();
      return send(res, 200, { ok: true });
    } catch {
      return send(res, 503, { ok: false });
    }
  }
  if (url !== "/v1/events") return send(res, 404, { error: "not found" });
  if (req.method !== "POST") return send(res, 405, { error: "use POST" });
  const type = (req.headers["content-type"] ?? "").split(";")[0]?.trim().toLowerCase();
  if (type !== "application/json" && type !== "text/plain") return send(res, 415, { error: "content type must be application/json or text/plain" });

  const userAgent = String(req.headers["user-agent"] ?? "");
  const body = await readBody(req);
  if (body === null) return send(res, 413, { error: "body larger than 32 KiB" });
  if (isCrawler(userAgent)) return send(res, 200, { stored: 0 });

  let parsed: unknown;
  try {
    parsed = JSON.parse(body);
  } catch {
    return send(res, 400, { error: "body is not valid JSON" });
  }
  const batch = validateBatch(parsed);
  if (!batch.ok) return send(res, 400, { error: batch.error });
  if (o.sources && !o.sources.has(batch.source)) return send(res, 404, { error: "unknown source" });

  const own = originHost(req.headers.origin);
  const session = sessionKey(o.secret, utcDay(new Date()), batch.source, address(req, o.trustProxy), userAgent);
  const rows: Row[] = [];
  const rejected: { index: number; reason: string }[] = [];
  batch.events.forEach((raw, index) => {
    const r = validateEvent(raw);
    if (!r.ok) return void rejected.push({ index, reason: r.reason });
    const e = r.event;
    const referrerHost = e.referrerHost !== null && e.referrerHost === own ? null : e.referrerHost;
    rows.push({
      source: batch.source,
      name: e.name,
      params: e.params,
      session,
      path: e.path,
      referrer_host: referrerHost,
      network: detectNetwork(referrerHost, userAgent, e.utmSource),
      utm_source: e.utmSource,
      utm_medium: e.utmMedium,
      utm_campaign: e.utmCampaign,
      language: e.language,
    });
  });
  try {
    await o.store.insert(rows);
  } catch (err) {
    // Only the error code: a database message may quote the row.
    o.log(`insert failed (${(err as { code?: string }).code ?? "unknown"})`);
    return send(res, 503, { error: "storage unavailable" });
  }
  send(res, 200, { stored: rows.length, ...(rejected.length ? { rejected } : {}) });
}

export function createServer(o: Options): http.Server {
  const server = http.createServer((req, res) => {
    handle(o, req, res).catch(() => {
      o.log("request failed");
      if (!res.headersSent) send(res, 500, { error: "internal error" });
      else res.end();
    });
  });
  server.requestTimeout = 15_000;
  return server;
}
