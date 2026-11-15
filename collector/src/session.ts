import { createHmac } from "node:crypto";

/**
 * A key that groups one visitor's events for one UTC day without storing who they are:
 * HMAC(dailySecret, source|address|user-agent), cut to 16 bytes. The secret rotates daily, so the
 * key cannot be linked across days; address and user agent are used here and never kept.
 */
export function sessionKey(secret: string, day: string, source: string, address: string, userAgent: string): string {
  const daily = createHmac("sha256", secret).update(day).digest();
  return createHmac("sha256", daily).update(`${source}|${address}|${userAgent}`).digest().subarray(0, 16).toString("hex");
}

export const utcDay = (d: Date): string => d.toISOString().slice(0, 10);
