import { describe, expect, it } from "vitest";
import { openCountryLookup } from "../src/geo.js";

// Needs a country database: ANALYTICS_TEST_GEOIP_DB=/path/country.mmdb (tool/fetch-geoip.mjs downloads one).
const DB = process.env["ANALYTICS_TEST_GEOIP_DB"];

describe.skipIf(!DB)("openCountryLookup", () => {
  it("finds a country for IPv4, IPv4-mapped IPv6 and IPv6, null for private and bad addresses", async () => {
    const country = await openCountryLookup(DB!);
    expect(country("8.8.8.8")).toBe("US");
    expect(country("::ffff:8.8.8.8")).toBe("US");
    expect(country("2a02:2378:1000::1")).toBe("UA");
    expect(country("10.0.0.1")).toBeNull();
    expect(country("not an address")).toBeNull();
  });
});
