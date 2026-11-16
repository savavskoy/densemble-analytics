# Privacy and limits

## What is stored

Only what is in the [table](reading-the-data.md#columns): the event, its parameters, the page path, the referrer
host, the network, the `utm_*` values, the language, the source and the arrival time.

## What is not stored

- The visitor's address and user agent. They are used in memory to build the session key and then dropped.
  They are not written to the database or to logs.
- Cookies, local storage or any identifier on the visitor's device.
- Full referrer URLs, query strings or fragments.

## How sessions work

The session key is a truncated HMAC of the source, the address and the user agent, with a secret that changes
every UTC day. It links one visitor's events within a day and cannot be turned back into an address. Nothing
links a visitor across days.

## Your responsibility

Do not put personal data (names, e-mail addresses, free text typed by a user) into `params`. The collector
stores whatever scalar values you send.

## Known limits

- Ad blockers can block the client; those visits are missing. A subdomain of your own site helps.
- A returning visitor looks new after 00:00 UTC.
- Crawlers are recognised by user agent only; unusual bots can slip in.
- The data is as private as your database: restrict who can read `analytics.events`.
