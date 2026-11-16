# Event format

The collector speaks one HTTP call. Use it from any language, a server, a script or a no-code tool.

## Request

`POST /v1/events` with `Content-Type: application/json` or `text/plain` (for `sendBeacon`).
Body at most 32 KiB and 50 events.

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

| Field | Rule |
| --- | --- |
| `source` | Which site or app. Must be on the allow-list if the collector has one. |
| `name` | Required. `^[a-z][a-z0-9_]{0,63}$`. |
| `params` | Optional. Flat, up to 20 keys; values are strings (up to 200 characters), numbers or booleans. |
| `path` | Optional. Starts with `/`, no `?` or `#`. |
| `referrer` | Optional. The full referrer URL; only its host is stored. |
| `utm` | Optional. `source`, `medium`, `campaign`. |
| `language` | Optional. For example `uk`. |

The time is set by the collector when the event arrives.

## Answer

`200 {"stored":n,"rejected":[{"index":i,"reason":"..."}]}`. Each event is checked on its own, so one bad event
does not lose the others.

| Status | Meaning |
| --- | --- |
| `400` | Body is not valid JSON or has the wrong shape |
| `404` | Unknown source or path |
| `405` | Wrong method |
| `413` | Body too large |
| `415` | Wrong content type |
| `503` | Database unavailable |

Crawlers get `200 {"stored":0}`. Send a real browser `User-Agent` when testing with curl.

## Other endpoints

- `GET /healthz` returns `200` when the collector and the database are up, `503` otherwise.
- `OPTIONS` is answered, and every response allows any origin, so browsers can call it from your site.
