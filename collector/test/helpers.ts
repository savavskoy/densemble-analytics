import type { AddressInfo } from "node:net";
import pg from "pg";
import { createStore, type Row, type Store } from "../src/db.js";
import { createServer } from "../src/server.js";

export const TEST_DB_URL = process.env["ANALYTICS_TEST_DATABASE_URL"];
export const CHROME_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

export interface Running {
  url: string;
  logs: string[];
  stop(): Promise<void>;
}

export async function start(store: Store, extra: { sources?: string[]; trustProxy?: boolean; secret?: string } = {}): Promise<Running> {
  const logs: string[] = [];
  const server = createServer({
    store,
    secret: extra.secret ?? "test-secret",
    sources: extra.sources ? new Set(extra.sources) : null,
    trustProxy: extra.trustProxy ?? false,
    log: (m) => logs.push(m),
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const port = (server.address() as AddressInfo).port;
  return { url: `http://127.0.0.1:${port}`, logs, stop: () => new Promise((r) => server.close(() => r())) };
}

/** A store that keeps rows in memory, for tests that do not need a database. */
export function memoryStore(): Store & { rows: Row[] } {
  const rows: Row[] = [];
  return { rows, ping: async () => {}, insert: async (r) => void rows.push(...r) };
}

export async function post(base: string, body: unknown, headers: Record<string, string> = {}) {
  const res = await fetch(`${base}/v1/events`, {
    method: "POST",
    headers: { "content-type": "application/json", "user-agent": CHROME_UA, ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? (JSON.parse(text) as Record<string, any>) : {}, headers: res.headers };
}

export const batch = (events: unknown[], source = "my-site") => ({ source, events });

/** A fresh schema in the test database; dropped by drop(). */
export async function testDb() {
  const schema = `t_${Math.random().toString(36).slice(2, 10)}`;
  const pool = new pg.Pool({ connectionString: TEST_DB_URL, max: 4 });
  const store = await createStore(pool, schema);
  return {
    pool,
    store,
    schema,
    rows: async () => (await pool.query(`select * from ${schema}.events order by id`)).rows as Record<string, any>[],
    drop: async () => {
      await pool.query(`drop schema ${schema} cascade`);
      await pool.end();
    },
  };
}
