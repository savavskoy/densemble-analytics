# Deployment

The collector is one container plus a PostgreSQL database. The bundled [`docker-compose.yml`](../docker-compose.yml)
is a good starting point; for production change the points below.

## Settings

All settings are environment variables of the collector.

| Variable | Meaning |
| --- | --- |
| `ANALYTICS_DATABASE_URL` | Required. PostgreSQL connection string. |
| `ANALYTICS_SECRET` | Set a long random value. Without it a new secret is made at each start, so sessions break at every restart. |
| `ANALYTICS_SOURCES` | Comma-separated list of allowed sources. Empty means any source is accepted. |
| `ANALYTICS_TRUST_PROXY` | `1` behind your own reverse proxy: the visitor address is read from `X-Forwarded-For`. |
| `ANALYTICS_GEOIP_DB` | Path to a MaxMind-format country database. The image sets it to the bundled DB-IP Country Lite; unset or unreadable means no countries. |
| `PORT` | Listening port, default `8080`. |

Set `ANALYTICS_TRUST_PROXY=1` only when a proxy you control sets `X-Forwarded-For`. Without a proxy leave it
unset. If it is wrong, every visitor looks like the proxy and all sessions merge into one.

## Checklist

1. **Database.** Create a PostgreSQL database and a user that can create a schema. The collector creates
   `analytics.events` and its indexes on start. Back the database up like any other.
2. **HTTPS.** Put the collector behind a reverse proxy with a certificate. A page served over HTTPS cannot
   call a plain `http://` collector.
3. **Your own domain.** Prefer a subdomain of your site, for example `stats.example.com`. Ad blockers block
   well-known analytics hosts more often than your own.
4. **Secret and sources.** Set `ANALYTICS_SECRET` and `ANALYTICS_SOURCES`.
5. **Health.** Point your monitoring at `GET /healthz`. The image has a built-in healthcheck.

## Image

`collector/Dockerfile` builds a small non-root image (Node 24). Build it from the repository root:
`docker build -t densemble-analytics-collector collector`. The build downloads DB-IP Country Lite of the
current month (CC BY 4.0: show "IP Geolocation by DB-IP" with a link to <https://db-ip.com> wherever you show
countries). If the download fails the image is still built, without countries. Rebuild monthly to keep it fresh.

## Several environments

Run one collector and one database per environment. See [Environments](environments.md).
