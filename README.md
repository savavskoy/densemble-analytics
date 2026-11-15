# Densemble Analytics

Small web and app analytics that live in your own PostgreSQL. A client sends an event, a tiny collector
validates it, and it lands as one row in one table. You read the data with your own SQL.

The two things it is built to answer: **which network a visitor came from** (Threads, Instagram, Telegram,
Google, a newsletter, direct) and **what they did in the session**.

**Privacy.** No cookies, no third party. The visitor's address and user agent are used in memory to make a
session key (a hash that changes every UTC day) and are never stored or logged. Crawlers are ignored.

## Start in five minutes

You need Docker.

```sh
docker compose up --build -d     # Postgres 17 and the collector on :8080
# ports taken? COLLECTOR_PORT=8081 POSTGRES_PORT=55433 docker compose up --build -d

curl -s -A "Mozilla/5.0 (iPhone) Instagram 350.0" -X POST http://localhost:8080/v1/events \
  -H 'content-type: application/json' \
  -d '{"source":"my-site","events":[{"name":"page_view","path":"/","referrer":"https://l.threads.net/"}]}'
# {"stored":1}

docker compose exec db psql -U analytics -c "select name, path, network from analytics.events"
```

`-A` matters: plain `curl` is treated as a crawler and its events are dropped (`{"stored":0}`).

## Event format

`POST /v1/events`, `application/json` or `text/plain` (for `sendBeacon`), at most 32 KiB and 50 events.

```json
{
  "source": "my-site",
  "events": [
    {
      "name": "button_click",
      "params": { "id": "subscribe" },
      "path": "/pricing",
      "referrer": "https://www.threads.net/",
      "utm": { "source": "newsletter", "medium": "email", "campaign": "nov" },
      "language": "uk"
    }
  ]
}
```

- `name` is required: `^[a-z][a-z0-9_]{0,63}$`. Everything else is optional.
- `params`: flat, up to 20 keys, values are strings (up to 200 characters), numbers or booleans.
- `path` starts with `/` and has no `?` or `#`.
- Answer: `200 {"stored":n,"rejected":[{"index":i,"reason":"..."}]}`. Every event is checked on its own, so one bad
  event does not lose the others. Other statuses: `400` bad body, `404` unknown source, `413` too large,
  `415` wrong content type.

Settings (environment): `ANALYTICS_DATABASE_URL` (required), `PORT` (8080), `ANALYTICS_SECRET` (set a long random
value; otherwise sessions restart with each start), `ANALYTICS_SOURCES` (comma-separated allow-list; empty means
any), `ANALYTICS_TRUST_PROXY=1` (read the address from `X-Forwarded-For` behind your own reverse proxy).

## Dart client

[`clients/dart/densemble_analytics`](clients/dart/densemble_analytics) sends events from Dart web apps
and never throws (Flutter and mobile are not supported yet). See its README for the exact API; the idea:

```dart
final analytics = WebAnalytics.create(
  endpoint: Uri.parse('https://analytics.example.com/v1/events'),
  source: 'my-site',
);
analytics.trackPageView();
analytics.track(ButtonClick('subscribe'));
```

## The table

`analytics.events`, created at start:

| column | meaning |
| --- | --- |
| `id`, `at` | row id, time of arrival |
| `source` | your site or app, as sent |
| `name`, `params` | what happened; `params` is `jsonb` |
| `session` | one visitor for one UTC day (a hash, not an identity) |
| `path` | page path |
| `referrer_host`, `network` | where from: `threads`, `instagram`, `facebook`, `telegram`, `google`, ..., the `utm_source`, `other`, or `direct` |
| `utm_source`, `utm_medium`, `utm_campaign`, `language` | as sent |

`network` comes from the referrer host; if there is none, from the in-app browser named in the user agent
(Instagram and Facebook often send no referrer); then from `utm_source`; then `direct`. A referrer on the
site's own host is ignored.

```sql
-- sessions per network per day
select at::date as day, network, count(distinct session) as sessions
from analytics.events where name = 'page_view'
group by 1, 2 order by 1 desc, 3 desc;

-- one session's path
select at, name, path, params from analytics.events
where session = '<session>' order by at;

-- split a session into visits after 30 minutes of silence
select session, visit, min(at) as started, count(*) as events
from (
  select *, count(*) filter (where gap > interval '30 minutes' or gap is null)
              over (partition by session order by at) as visit
  from (select *, at - lag(at) over (partition by session order by at) as gap from analytics.events) e
) v
group by session, visit order by started desc;
```

## Known limits

- Ad blockers can block the client; those visits are simply missing.
- No cookies means a returning visitor looks new after a day (the session key rotates at 00:00 UTC).
- Crawlers are recognised by user agent only; unusual bots can slip in.

## Reading the data with AI agents

Because the data is plain SQL in your own database, an agent with read access can answer questions such as "which
network brought the most readers last week". The author reads it this way with Densemble, a personal team of AI
agents; any tool that can run SQL works the same.

## Credits

Cookie-less sessions from a daily-rotating hash follow the public write-ups of
[Plausible](https://plausible.io) and [Fathom](https://usefathom.com). The crawler list is derived from
[crawler-user-agents](https://github.com/monperrus/crawler-user-agents) (MIT). Built with
[node-postgres](https://node-postgres.com) and [zod](https://zod.dev). MIT license, see [LICENSE](LICENSE).
