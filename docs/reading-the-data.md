# Reading the data

Everything is in one table, `analytics.events`. Open it with `psql`, a SQL client or an AI agent that can run SQL.

## Columns

| Column | Meaning |
| --- | --- |
| `id`, `at` | Row id and the time the collector received the event |
| `source` | Your site or app, as sent |
| `name`, `params` | What happened; `params` is `jsonb` |
| `session` | One visitor for one UTC day (a hash, not an identity) |
| `path` | Page path |
| `referrer_host` | Host of the referrer, if any |
| `network` | Where the visitor came from (see below) |
| `utm_source`, `utm_medium`, `utm_campaign`, `language` | As sent |
| `country` | ISO 3166-1 alpha-2 code of the visitor's country (`ES`, `UA`), from the address; null when unknown or when countries are off |

## How `network` is decided

In this order:

1. The referrer host: `threads`, `instagram`, `facebook`, `x`, `linkedin`, `telegram`, `youtube`, `tiktok`,
   `reddit`, `google`, `bing`, and others. An unknown referrer is `other`.
2. The in-app browser named in the user agent. Instagram and Facebook often send no referrer.
3. `utm_source`, if present.
4. Otherwise `direct`.

A referrer on your own site is ignored, so internal navigation does not count as a source.

## Useful queries

```sql
-- sessions per network per day
select at::date as day, network, count(distinct session) as sessions
from analytics.events where name = 'page_view'
group by 1, 2 order by 1 desc, 3 desc;

-- one session, step by step
select at, name, path, params from analytics.events
where session = '<session>' order by at;

-- split sessions into visits after 30 minutes of silence
select session, visit, min(at) as started, count(*) as events
from (
  select *, count(*) filter (where gap > interval '30 minutes' or gap is null)
              over (partition by session order by at) as visit
  from (select *, at - lag(at) over (partition by session order by at) as gap from analytics.events) e
) v
group by session, visit order by started desc;
```

## Tips

- Always filter by `source` when one database holds several sites.
- A session is one visitor for one UTC day, so a visitor who comes back the next day looks new.
