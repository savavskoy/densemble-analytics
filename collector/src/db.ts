import pg from "pg";

export interface Row {
  source: string;
  name: string;
  params: Record<string, unknown>;
  session: string;
  path: string | null;
  referrer_host: string | null;
  network: string;
  utm_source: string | null;
  utm_medium: string | null;
  utm_campaign: string | null;
  language: string | null;
  country: string | null;
}

export interface Store {
  ping(): Promise<void>;
  insert(rows: Row[]): Promise<void>;
}

const COLUMNS = ["source", "name", "params", "session", "path", "referrer_host", "network", "utm_source", "utm_medium", "utm_campaign", "language", "country"] as const;

/** Creates the schema and the table when missing, and returns a Store over the pool. */
export async function createStore(pool: pg.Pool, schema = "analytics"): Promise<Store> {
  if (!/^[a-z_][a-z0-9_]*$/.test(schema)) throw new Error("bad schema name");
  await pool.query(`create schema if not exists ${schema}`);
  await pool.query(`create table if not exists ${schema}.events (
    id bigserial primary key,
    source text not null,
    name text not null,
    params jsonb not null default '{}',
    at timestamptz not null default now(),
    session text not null,
    path text,
    referrer_host text,
    network text not null,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    language text,
    country text
  )`);
  await pool.query(`alter table ${schema}.events add column if not exists country text`);
  await pool.query(`create index if not exists events_source_at on ${schema}.events (source, at)`);
  await pool.query(`create index if not exists events_session_at on ${schema}.events (session, at)`);
  return {
    async ping() {
      await pool.query("select 1");
    },
    async insert(rows) {
      if (rows.length === 0) return;
      const n = COLUMNS.length;
      const values = rows.map((_, i) => `(${COLUMNS.map((_c, j) => `$${i * n + j + 1}`).join(",")})`).join(",");
      const args = rows.flatMap((r) => COLUMNS.map((c) => (c === "params" ? JSON.stringify(r.params) : r[c])));
      await pool.query(`insert into ${schema}.events (${COLUMNS.join(",")}) values ${values}`, args);
    },
  };
}
