# Environments (staging and production)

You can keep staging and production analytics completely apart while using the same library. The client only
needs to know **where to send** and **which source name to use**; both are chosen when you build the app.

```
staging site ──► collector (staging) ──► database analytics_staging
prod site    ──► collector (prod)    ──► database analytics_prod
```

## Recommended: one collector and one database per environment

| | staging | production |
| --- | --- | --- |
| Collector address | `https://stats-staging.example.com/v1/events` | `https://stats.example.com/v1/events` |
| `ANALYTICS_DATABASE_URL` | `.../analytics_staging` | `.../analytics_prod` |
| `ANALYTICS_SECRET` | its own random value | another random value |
| `ANALYTICS_SOURCES` | `my-site-staging` | `my-site` |

Build the client once per environment (see [Dart client](dart-client.md#choose-the-collector-at-build-time)):

```sh
# staging
dart compile js web/main.dart -o web/main.dart.js \
  -DANALYTICS_ENDPOINT=https://stats-staging.example.com/v1/events -DANALYTICS_SOURCE=my-site-staging
# production
dart compile js web/main.dart -o web/main.dart.js \
  -DANALYTICS_ENDPOINT=https://stats.example.com/v1/events -DANALYTICS_SOURCE=my-site
```

Use different `source` names even with separate databases. If an event ever lands in the wrong place, the name
shows it and the allow-list rejects it.

## Local development

Do not set the endpoint. The client then does nothing, so local runs and tests never send data.

## Lighter option: one collector, one database

Allow both sources (`ANALYTICS_SOURCES=my-site,my-site-staging`) and filter in SQL with `where source = 'my-site'`.
This is simpler to run, but the data is shared, so it is not a real separation.
