// Where a visitor came from: referrer host first, then the in-app browser marker, then utm_source.
const HOSTS: [RegExp, string][] = [
  [/(^|\.)threads\.(net|com)$/, "threads"],
  [/(^|\.)instagram\.com$/, "instagram"],
  [/(^|\.)(facebook|fb)\.com$|^fb\.me$/, "facebook"],
  [/(^|\.)twitter\.com$|(^|\.)x\.com$|^t\.co$/, "x"],
  [/(^|\.)linkedin\.com$|^lnkd\.in$/, "linkedin"],
  [/^t\.me$|(^|\.)telegram\.(org|me)$/, "telegram"],
  [/(^|\.)youtube\.com$|^youtu\.be$/, "youtube"],
  [/(^|\.)tiktok\.com$/, "tiktok"],
  [/(^|\.)reddit\.com$/, "reddit"],
  [/(^|\.)bsky\.app$/, "bluesky"],
  [/(^|\.)pinterest\.[a-z.]+$/, "pinterest"],
  [/(^|\.)vk\.com$/, "vk"],
  [/(^|\.)google\.[a-z.]+$/, "google"],
  [/(^|\.)bing\.com$/, "bing"],
  [/(^|\.)duckduckgo\.com$/, "duckduckgo"],
  [/(^|\.)yandex\.[a-z.]+$|^ya\.ru$/, "yandex"],
  [/(^|\.)yahoo\.[a-z.]+$/, "yahoo"],
  [/(^|\.)ecosia\.org$/, "ecosia"],
];

// In-app browsers often send no referrer, but name the app in the user agent.
const IN_APP: [RegExp, string][] = [
  [/barcelona|threads/i, "threads"],
  [/instagram/i, "instagram"],
  [/fban|fbav|fb_iab/i, "facebook"],
  [/telegram/i, "telegram"],
  [/twitter/i, "x"],
  [/linkedinapp/i, "linkedin"],
  [/musical_ly|bytedance|tiktok/i, "tiktok"],
];

export function detectNetwork(referrerHost: string | null, userAgent: string, utmSource: string | null): string {
  if (referrerHost) for (const [re, name] of HOSTS) if (re.test(referrerHost)) return name;
  for (const [re, name] of IN_APP) if (re.test(userAgent)) return name;
  if (utmSource) return utmSource;
  return referrerHost ? "other" : "direct";
}

const BOTS = [
  "bot", "crawl", "spider", "slurp", "facebookexternalhit", "embedly", "whatsapp", "preview", "headless", "phantomjs",
  "lighthouse", "pagespeed", "python-", "curl/", "wget/", "go-http-client", "libwww", "uptime", "pingdom", "scrapy",
  "axios/", "node-fetch", "undici", "postman", "feedfetcher", "feedly", "ahrefs", "semrush", "mj12",
];

/** An empty user agent or a well-known crawler or tool. */
export function isCrawler(userAgent: string): boolean {
  const ua = userAgent.trim().toLowerCase();
  return ua === "" || BOTS.some((b) => ua.includes(b));
}
