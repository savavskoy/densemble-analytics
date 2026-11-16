# Densemble Analytics

Small web and app analytics that live in your own PostgreSQL. A client sends an event, a tiny collector
validates it, and it lands as one row in one table. You read the data with your own SQL.

It is built to answer two questions: **which network a visitor came from** (Threads, Instagram, Telegram,
Google, a newsletter, direct) and **what they did in the session**.

No cookies and no third party. The visitor's address and user agent are never stored.

```
your site or app ──► collector (POST /v1/events) ──► your PostgreSQL
```

## Documentation

| I want to... | Read |
| --- | --- |
| Try it locally in five minutes | [Getting started](docs/getting-started.md) |
| Add it to a Dart web project | [Dart client](docs/dart-client.md) |
| Send events from another language or tool | [Event format](docs/event-format.md) |
| Run the collector for real (HTTPS, proxy, secrets) | [Deployment](docs/deployment.md) |
| Keep staging and production separate | [Environments](docs/environments.md) |
| Look at the data and answer questions with SQL | [Reading the data](docs/reading-the-data.md) |
| Know what is stored and what is not | [Privacy and limits](docs/privacy-and-limits.md) |

## Repository

- [`collector/`](collector): the collector (TypeScript, Node.js)
- [`clients/dart/densemble_analytics/`](clients/dart/densemble_analytics): the Dart web client
- [`example/site/`](example/site): the smallest page that reports events
- [`docker-compose.yml`](docker-compose.yml): PostgreSQL and the collector for local use

MIT license, see [LICENSE](LICENSE). Credits are in [NOTICE](NOTICE.md).
