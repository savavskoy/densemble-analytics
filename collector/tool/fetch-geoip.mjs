// Downloads DB-IP Country Lite (CC BY 4.0, https://db-ip.com) for this or last month into the given path.
// A failed download leaves no file: the collector then runs without countries.
import { writeFile } from "node:fs/promises";
import { gunzipSync } from "node:zlib";

const out = process.argv[2];
const months = [0, 1].map((back) => {
  const d = new Date();
  d.setUTCDate(1);
  d.setUTCMonth(d.getUTCMonth() - back);
  return d.toISOString().slice(0, 7);
});
for (const month of months) {
  try {
    const res = await fetch(`https://download.db-ip.com/free/dbip-country-lite-${month}.mmdb.gz`);
    if (!res.ok) continue;
    await writeFile(out, gunzipSync(Buffer.from(await res.arrayBuffer())));
    console.log(`geoip: dbip-country-lite-${month}`);
    process.exit(0);
  } catch {
    // try the previous month
  }
}
console.log("geoip: download failed, countries are off");
