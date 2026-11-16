# Getting started

Run the whole thing on your machine, send one event and see the row. You need Docker.

## 1. Start the collector and a database

```sh
docker compose up --build -d
```

This starts PostgreSQL 17 and the collector on `http://localhost:8080`. The collector creates the
`analytics.events` table itself on start. If the ports are taken:
`COLLECTOR_PORT=8081 POSTGRES_PORT=55433 docker compose up --build -d`.

## 2. Send an event

```sh
curl -s -A "Mozilla/5.0 (iPhone) Instagram 350.0" -X POST http://localhost:8080/v1/events \
  -H 'content-type: application/json' \
  -d '{"source":"my-site","events":[{"name":"page_view","path":"/","referrer":"https://l.threads.net/"}]}'
```

Expected answer: `{"stored":1}`.

Always pass `-A`. A plain `curl` is treated as a crawler and its events are dropped (`{"stored":0}`).

## 3. See the row

```sh
docker compose exec db psql -U analytics -c "select name, path, network from analytics.events"
```

You should see `page_view | / | threads`.

## Next

- Report from a Dart web app: [Dart client](dart-client.md).
- Report from anything else: [Event format](event-format.md).
- Put it on a server: [Deployment](deployment.md).
