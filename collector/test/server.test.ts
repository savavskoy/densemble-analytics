import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { batch, CHROME_UA, memoryStore, post, start, type Running } from "./helpers.js";

const store = memoryStore();
let app: Running;
beforeAll(async () => void (app = await start(store, { sources: ["my-site"] })));
afterAll(() => app.stop());

describe("HTTP", () => {
  it("200: stores valid events and reports rejected ones by index", async () => {
    const before = store.rows.length;
    const r = await post(app.url, batch([{ name: "page_view", path: "/" }, { name: "Bad" }, { name: "click" }]));
    expect(r.status).toBe(200);
    expect(r.json["stored"]).toBe(2);
    expect(r.json["rejected"]).toEqual([{ index: 1, reason: expect.stringContaining("name:") }]);
    expect(store.rows.length - before).toBe(2);
  });

  it("accepts text/plain (sendBeacon)", async () => {
    const r = await post(app.url, JSON.stringify(batch([{ name: "x" }])), { "content-type": "text/plain;charset=UTF-8" });
    expect(r.status).toBe(200);
  });

  it("400 for broken JSON and for a bad envelope", async () => {
    expect((await post(app.url, "{nope")).status).toBe(400);
    expect((await post(app.url, { source: "my-site", events: [] })).status).toBe(400);
  });

  it("404 for an unknown source and an unknown path", async () => {
    expect((await post(app.url, batch([{ name: "x" }], "stranger"))).status).toBe(404);
    expect((await fetch(`${app.url}/nope`)).status).toBe(404);
  });

  it("413 for a body over 32 KiB", async () => {
    const r = await post(app.url, batch([{ name: "x", params: { a: "y".repeat(40000) } }]));
    expect(r.status).toBe(413);
  });

  it("415 for another content type", async () => {
    const r = await post(app.url, "a=b", { "content-type": "application/x-www-form-urlencoded" });
    expect(r.status).toBe(415);
  });

  it("answers OPTIONS and always allows any origin", async () => {
    const o = await fetch(`${app.url}/v1/events`, { method: "OPTIONS", headers: { origin: "https://example.com" } });
    expect(o.status).toBe(204);
    expect(o.headers.get("access-control-allow-origin")).toBe("*");
    const r = await post(app.url, batch([{ name: "x" }]));
    expect(r.headers.get("access-control-allow-origin")).toBe("*");
  });

  it("healthz answers 200", async () => {
    const r = await fetch(`${app.url}/healthz`);
    expect(r.status).toBe(200);
  });

  it("ignores crawlers: 200, stored 0, nothing kept", async () => {
    const before = store.rows.length;
    const r = await post(app.url, batch([{ name: "page_view" }]), { "user-agent": "Mozilla/5.0 (compatible; Googlebot/2.1)" });
    expect(r.status).toBe(200);
    expect(r.json).toEqual({ stored: 0 });
    expect(store.rows.length).toBe(before);
  });

  it("drops a referrer from the site's own host", async () => {
    await post(app.url, batch([{ name: "page_view", referrer: "https://my.example.com/a" }]), { origin: "https://my.example.com" });
    const row = store.rows.at(-1)!;
    expect(row.referrer_host).toBeNull();
    expect(row.network).toBe("direct");
  });

  it("detects the network from the referrer and from an in-app browser", async () => {
    await post(app.url, batch([{ name: "page_view", referrer: "https://www.threads.net/" }]));
    expect(store.rows.at(-1)!.network).toBe("threads");
    await post(app.url, batch([{ name: "page_view" }]), { "user-agent": `${CHROME_UA} Instagram 350.0` });
    expect(store.rows.at(-1)!.network).toBe("instagram");
  });

  it("gives one visitor one session key and two visitors two", async () => {
    await post(app.url, batch([{ name: "a" }, { name: "b" }]));
    const [a, b] = store.rows.slice(-2);
    await post(app.url, batch([{ name: "c" }]), { "user-agent": `${CHROME_UA} Other` });
    expect(a!.session).toBe(b!.session);
    expect(store.rows.at(-1)!.session).not.toBe(a!.session);
  });
});

describe("country", () => {
  it("stores the country of the forwarded address and never the address", async () => {
    const rows = memoryStore();
    const seen: string[] = [];
    const geo = await start(rows, {
      trustProxy: true,
      country: (a) => (seen.push(a), a === "203.0.113.7" ? "ES" : null),
    });
    try {
      await post(geo.url, batch([{ name: "page_view" }]), { "x-forwarded-for": "203.0.113.7, 10.0.0.1" });
      await post(geo.url, batch([{ name: "page_view" }]), { "x-forwarded-for": "198.51.100.1" });
      expect(rows.rows.map((r) => r.country)).toEqual(["ES", null]);
      expect(seen).toEqual(["203.0.113.7", "198.51.100.1"]);
      expect(JSON.stringify(rows.rows)).not.toContain("203.0.113.7");
    } finally {
      await geo.stop();
    }
  });

  it("is null without a lookup", async () => {
    await post(app.url, batch([{ name: "page_view" }]));
    expect(store.rows.at(-1)!.country).toBeNull();
  });
});
