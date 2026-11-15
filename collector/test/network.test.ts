import { describe, expect, it } from "vitest";
import { detectNetwork, isCrawler } from "../src/network.js";
import { sessionKey } from "../src/session.js";

const IG = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Instagram 350.0.0";
const FB = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/130 Mobile Safari/537.36 [FBAN/FB4A;FBAV/480.0.0]";
const CH = "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/130 Safari/537.36";

describe("detectNetwork", () => {
  it.each([
    ["threads.net", CH, null, "threads"],
    ["l.instagram.com", CH, null, "instagram"],
    ["l.facebook.com", CH, null, "facebook"],
    ["t.me", CH, null, "telegram"],
    ["www.google.com", CH, null, "google"],
    ["t.co", CH, null, "x"],
    [null, IG, null, "instagram"],
    [null, FB, null, "facebook"],
    [null, CH, "newsletter", "newsletter"],
    [null, CH, null, "direct"],
    ["blog.example.com", CH, null, "other"],
  ])("referrer %s, utm %s -> %s", (host, ua, utm, expected) => {
    expect(detectNetwork(host, ua, utm)).toBe(expected);
  });

  it("prefers the referrer over the user agent and utm", () => {
    expect(detectNetwork("threads.net", IG, "x")).toBe("threads");
  });
});

describe("isCrawler", () => {
  it.each(["", "curl/8.7.1", "Googlebot/2.1", "Mozilla/5.0 (compatible; bingbot/2.0)", "WhatsApp/2.23"])("%j is a crawler", (ua) => {
    expect(isCrawler(ua)).toBe(true);
  });
  it("lets a browser through", () => expect(isCrawler(CH)).toBe(false));
});

describe("sessionKey", () => {
  const k = (o: Partial<Record<string, string>> = {}) =>
    sessionKey(o["secret"] ?? "s", o["day"] ?? "2026-11-15", o["source"] ?? "my-site", o["ip"] ?? "203.0.113.7", o["ua"] ?? CH);
  it("is stable for the same visitor", () => expect(k()).toBe(k()));
  it("is 32 hex characters", () => expect(k()).toMatch(/^[0-9a-f]{32}$/));
  it("differs between visitors", () => {
    expect(k({ ip: "203.0.113.8" })).not.toBe(k());
    expect(k({ ua: IG })).not.toBe(k());
    expect(k({ source: "other" })).not.toBe(k());
  });
  it("changes with the day and with the secret", () => {
    expect(k({ day: "2026-11-16" })).not.toBe(k());
    expect(k({ secret: "t" })).not.toBe(k());
  });
});
