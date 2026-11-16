# densemble_analytics

Minimal analytics client for Dart web apps. Each event is sent at once to a collector
(`POST /v1/events`), which writes it to a database. No cookies, no ids on the client.

## Install

The package is not on pub.dev. Use it from Git:

```yaml
dependencies:
  densemble_analytics:
    git:
      url: https://github.com/savavskoy/densemble-analytics.git
      path: clients/dart/densemble_analytics
```

## Web setup

```dart
import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';

final analytics = WebAnalytics.create(
  endpoint: Uri.parse('https://analytics.example.com/v1/events'),
  source: 'my-site',
);
analytics.trackPageView();
```

Without an endpoint, a source or a browser `window` you get `NoopAnalytics`, so the same
code is safe in tests and server rendering (do not import `web.dart` in code that runs on
a server).

## Events

Built in: `ScreenView`, `ButtonClick('id')`, `FormSubmit('id')`, `NavigationClick('/to')`.
Your own: `analytics.track(AnalyticsEvent('video_played', params: {'seconds': 12}))`.
Names match `^[a-z][a-z0-9_]{0,63}$`; params are flat (at most 20 string, number or bool
values). Do not put personal data in them. `track` never throws and never waits.

## Not supported yet

Flutter and mobile apps.

## License

MIT
