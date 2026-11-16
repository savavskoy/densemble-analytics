# Documentation

Pick the page for what you are doing.

| I want to... | Read |
| --- | --- |
| Try it locally in five minutes | [Getting started](getting-started.md) |
| Add it to a Dart web project | [Dart client](dart-client.md) |
| Send events from another language or tool | [Event format](event-format.md) |
| Run the collector for real (HTTPS, proxy, secrets) | [Deployment](deployment.md) |
| Keep staging and production separate | [Environments](environments.md) |
| Look at the data and answer questions with SQL | [Reading the data](reading-the-data.md) |
| Know what is stored and what is not | [Privacy and limits](privacy-and-limits.md) |

## How it fits together

```
your site or app ──► collector (POST /v1/events) ──► your PostgreSQL (analytics.events)
```

- The **client** is optional. Anything that can send an HTTP request can report events.
- The **collector** is one small Node.js service. It checks events and writes rows.
- The **database** is your own PostgreSQL. You read it with plain SQL.
