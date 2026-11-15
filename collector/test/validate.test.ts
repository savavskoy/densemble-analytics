import { describe, expect, it } from "vitest";
import { validateBatch, validateEvent } from "../src/validate.js";

const reason = (e: unknown) => {
  const r = validateEvent(e);
  return r.ok ? null : r.reason;
};

describe("validateEvent", () => {
  it("accepts a full event and shapes it", () => {
    const r = validateEvent({
      name: "page_view",
      params: { a: "x", n: 1, b: true },
      path: "/blog/post-1",
      referrer: "https://WWW.Example.com/some/page?q=1",
      utm: { source: "Newsletter", medium: "email", campaign: "" },
      language: "uk",
    });
    expect(r).toEqual({
      ok: true,
      event: {
        name: "page_view",
        params: { a: "x", n: 1, b: true },
        path: "/blog/post-1",
        referrerHost: "www.example.com",
        utmSource: "newsletter",
        utmMedium: "email",
        utmCampaign: null,
        language: "uk",
      },
    });
  });

  it("needs only a name", () => {
    expect(validateEvent({ name: "ping" }).ok).toBe(true);
  });

  it.each([
    [{}, "name: required"],
    [{ name: "Page" }, "name:"],
    [{ name: "1a" }, "name:"],
    [{ name: "a".repeat(65) }, "name:"],
    [{ name: "a", path: "x" }, "path:"],
    [{ name: "a", path: "/x?y=1" }, "path:"],
    [{ name: "a", path: "/x#top" }, "path:"],
    [{ name: "a", params: { k: { nested: 1 } } }, "params.k:"],
    [{ name: "a", params: { k: "x".repeat(201) } }, "params.k:"],
    [{ name: "a", params: { k: "bad\u0000" } }, "params.k:"],
    [{ name: "a", utm: { source: "x".repeat(101) } }, "utm.source:"],
    [{ name: "a", language: 5 }, "language:"],
    ["text", "event:"],
  ])("rejects %j with a reason starting %s", (event, start) => {
    expect(reason(event)).toMatch(new RegExp(`^${start.replace(/[.]/g, "\\.")}`));
  });

  it("rejects more than 20 params", () => {
    const params = Object.fromEntries(Array.from({ length: 21 }, (_, i) => [`k${i}`, i]));
    expect(reason({ name: "a", params })).toContain("params:");
  });

  it("ignores an unparseable referrer", () => {
    const r = validateEvent({ name: "a", referrer: "not a url" });
    expect(r.ok && r.event.referrerHost).toBeNull();
  });
});

describe("validateBatch", () => {
  it("accepts a normal batch", () => {
    expect(validateBatch({ source: "my-site", events: [{}] }).ok).toBe(true);
  });
  it.each([
    [null],
    [[]],
    [{ events: [{}] }],
    [{ source: "Bad Source!", events: [{}] }],
    [{ source: "my-site" }],
    [{ source: "my-site", events: [] }],
    [{ source: "my-site", events: Array(51).fill({}) }],
  ])("rejects %j", (b) => {
    expect(validateBatch(b).ok).toBe(false);
  });
});
