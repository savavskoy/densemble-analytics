import maxmind, { type CountryResponse } from "maxmind";

/** Turns a visitor address into an ISO 3166-1 alpha-2 country code, or null when it is unknown. */
export type CountryLookup = (address: string) => string | null;

/** Opens a MaxMind-format country database (DB-IP Country Lite or GeoLite2 Country). */
export async function openCountryLookup(path: string): Promise<CountryLookup> {
  const reader = await maxmind.open<CountryResponse>(path);
  return (address) => {
    const ip = address.startsWith("::ffff:") ? address.slice(7) : address;
    if (!maxmind.validate(ip)) return null;
    try {
      const code = reader.get(ip)?.country?.iso_code;
      return code && /^[A-Z]{2}$/.test(code) ? code : null;
    } catch {
      return null;
    }
  };
}
