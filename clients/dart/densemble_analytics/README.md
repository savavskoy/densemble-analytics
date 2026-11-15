# densemble_analytics

Minimal analytics client for Dart web apps. Each event is sent at once to a collector
(`POST /v1/events`), which writes it to a database. No cookies, no ids on the client.

## Install

```yaml
dependencies:
  densemble_analytics: ^0.1.0
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
