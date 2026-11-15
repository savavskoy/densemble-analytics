import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { batch, CHROME_UA, post, start, testDb, TEST_DB_URL, type Running } from "./helpers.js";

const ADDRESS = "198.51.100.77"; // documentation range; sent as X-Forwarded-For
const UA = `${CHROME_UA} SecretMarker/9.9.9`;

describe.skipIf(!TEST_DB_URL)("with PostgreSQL", () => {
  let db: Awaited<ReturnType<typeof testDb>>;
  let app: Running;
  beforeAll(async () => {
    db = await testDb();
    app = await start(db.store, { trustProxy: true });
  });
  afterAll(async () => {
    await app.stop();
    await db.drop();
  });

  it("writes a row with the expected fields", async () => {
    const r = await post(
      app.url,
      batch([
        {
          name: "button_click",
          params: { id: "buy", n: 2 },
          path: "/pricing",
          referrer: "https://www.threads.net/",
          utm: { source: "Launch", medium: "social", campaign: "nov" },
          language: "uk",
        },
      ]),
      { "x-forwarded-for": ADDRESS, "user-agent": UA },
    );
    expect(r.json).toEqual({ stored: 1 });
    const [row] = await db.rows();
    expect(row).toMatchObject({
      source: "my-site",
      name: "button_click",
      params: { id: "buy", n: 2 },
      path: "/pricing",
      referrer_host: "www.threads.net",
      network: "threads",
      utm_source: "launch",
      utm_medium: "social",
      utm_campaign: "nov",
      language: "uk",
    });
    expect(row!["session"]).toMatch(/^[0-9a-f]{32}$/);
    expect(row!["at"]).toBeInstanceOf(Date);
  });

  it("is safe to start twice (create if not exists)", async () => {
    const { createStore } = await import("../src/db.js");
    await createStore(db.pool, db.schema);
  });

  it("never stores the address or the user agent, sets no cookie, logs neither", async () => {
    const r = await post(app.url, batch([{ name: "page_view", path: "/" }]), { "x-forwarded-for": ADDRESS, "user-agent": UA });
    expect(r.headers.get("set-cookie")).toBeNull();
    // every row of every table in the schema, as text
    const tables = (await db.pool.query("select table_name from information_schema.tables where table_schema = $1", [db.schema])).rows;
    expect(tables.length).toBeGreaterThan(0);
    for (const { table_name } of tables) {
      const dump = (await db.pool.query(`select t::text as t from ${db.schema}."${table_name}" t`)).rows.map((x) => x.t).join("\n");
      expect(dump).not.toContain(ADDRESS);
      expect(dump).not.toContain("SecretMarker");
    }
    expect(app.logs.join("\n")).not.toContain(ADDRESS);
    expect(app.logs.join("\n")).not.toContain("SecretMarker");
  });

  it("a database failure gives 503 and logs only the code", async () => {
    await db.pool.query(`alter table ${db.schema}.events rename to events_moved`);
    const r = await post(app.url, batch([{ name: "x" }]), { "user-agent": UA });
    await db.pool.query(`alter table ${db.schema}.events_moved rename to events`);
    expect(r.status).toBe(503);
    expect(app.logs.join("\n")).toContain("insert failed (42P01)");
    expect(app.logs.join("\n")).not.toContain("SecretMarker");
  });
});
