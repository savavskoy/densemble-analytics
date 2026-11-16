# Dart client

For Dart web apps compiled to JavaScript. Flutter and mobile are not supported yet.
Any other language can use the [HTTP format](event-format.md) directly.

## Install

The package is not on pub.dev yet. Use it from Git:

```yaml
dependencies:
  densemble_analytics:
    git:
      url: https://github.com/savavskoy/densemble-analytics.git
      path: clients/dart/densemble_analytics
```

Or from a local copy: `path: ../densemble-analytics/clients/dart/densemble_analytics`.

## Use

```dart
import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';

final analytics = WebAnalytics.create(
  endpoint: const bool.hasEnvironment('ANALYTICS_ENDPOINT')
      ? Uri.parse(const String.fromEnvironment('ANALYTICS_ENDPOINT'))
      : null,
  source: const String.fromEnvironment('ANALYTICS_SOURCE'),
);

analytics.trackPageView();              // once per page; call again after in-page navigation
analytics.track(ButtonClick('subscribe'));
analytics.track(FormSubmit('signup'));  // never put personal data into an event
analytics.track(const AnalyticsEvent('video_played', params: {'seconds': 12}));
```

Built-in events: `ScreenView`, `ButtonClick`, `FormSubmit`, `NavigationClick`. Your own events use
`AnalyticsEvent(name, params: {...})`; the rules for names and params are in [Event format](event-format.md).

## Choose the collector at build time

The endpoint and source are compile-time values, so one codebase can report to different collectors:

```sh
dart compile js web/main.dart -o web/main.dart.js \
  -DANALYTICS_ENDPOINT=https://analytics.example.com/v1/events \
  -DANALYTICS_SOURCE=my-site
```

If the endpoint or source is missing (local development, tests), `WebAnalytics.create` returns a client that
does nothing. See [Environments](environments.md).

## Behaviour to know

- `track` never throws and never waits. A failed send is silent.
- The referrer and `utm_*` parameters are read once per page load and sent with the first event.
- When the page is hidden, pending events are sent with `sendBeacon`.
- Do not import `web.dart` in code that also runs on a server. Use `const NoopAnalytics()` there.

A complete page is in [`example/site`](../example/site).
