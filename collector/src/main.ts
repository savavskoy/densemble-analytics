import { randomBytes } from "node:crypto";
import pg from "pg";
import { createStore } from "./db.js";
import { createServer } from "./server.js";

const log = (m: string): void => console.log(`${new Date().toISOString()} ${m}`);

const url = process.env["ANALYTICS_DATABASE_URL"];
if (!url) {
  console.error("ANALYTICS_DATABASE_URL is required");
  process.exit(2);
}
let secret = process.env["ANALYTICS_SECRET"];
if (!secret) {
  secret = randomBytes(32).toString("hex");
  log("warning: ANALYTICS_SECRET not set; a random one is used, so sessions restart with every start");
}
const sources = process.env["ANALYTICS_SOURCES"]?.split(",").map((s) => s.trim()).filter(Boolean);

const pool = new pg.Pool({ connectionString: url, max: 5 });
pool.on("error", () => log("database connection error"));
const store = await createStore(pool);
const server = createServer({
  store,
  secret,
  sources: sources?.length ? new Set(sources) : null,
  trustProxy: process.env["ANALYTICS_TRUST_PROXY"] === "1",
  log,
});
const port = Number(process.env["PORT"] ?? 8080);
server.listen(port, () => log(`listening on ${port}`));

const stop = (): void => {
  server.close(() => void pool.end().then(() => process.exit(0)));
  setTimeout(() => process.exit(0), 5000).unref();
};
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
