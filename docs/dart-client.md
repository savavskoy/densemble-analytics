# Dart client

For Dart web apps compiled to JavaScript. Flutter and mobile are not supported yet.
Any other language can use the [HTTP format](event-format.md) directly.

## Install

The package is not on pub.dev. Use it from Git:

```yaml
dependencies:
  densemble_analytics:
    git:
      url: https://github.com/savavskoy/densemble-analytics.git
      path: clients/dart/densemble_analytics
```

Or from a local copy: `path: ../densemble-analytics/clients/dart/densemble_analytics`.

## Use

The package gives you one concrete class, `DensembleAnalytics`. It is not an interface: keep your
project's own analytics interface, and let one adapter of yours call this class. Then the rest of
your code does not depend on the package, and you can switch or combine analytics tools later.

```dart
// lib/analytics/site_analytics.dart: yours, no package import
abstract interface class SiteAnalytics {
  void track(String name, {Map<String, Object> params});
}

// lib/analytics/densemble_site_analytics.dart: the only file that imports the package
import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';

final class DensembleSiteAnalytics implements SiteAnalytics {
  DensembleSiteAnalytics(this._client);
  final DensembleAnalytics _client;

  @override
  void track(String name, {Map<String, Object> params = const {}}) => _client.track(name, params: params);
}

// browser entry point
final client = WebAnalytics.create(
  endpoint: const bool.hasEnvironment('ANALYTICS_ENDPOINT')
      ? Uri.parse(const String.fromEnvironment('ANALYTICS_ENDPOINT'))
      : null,
  source: const String.fromEnvironment('ANALYTICS_SOURCE'),
);
if (client != null) {
  client.trackPageView(); // once per page; call again after in-page navigation
  final SiteAnalytics analytics = DensembleSiteAnalytics(client);
  analytics.track('form_submit', params: {'id': 'signup'}); // never put personal data into an event
}
```

Event names and params follow the rules in [Event format](event-format.md). `page_view` (from
`trackPageView`) sends only the length of the page title.

## Choose the collector at build time

The endpoint and source are compile-time values, so one codebase can report to different collectors:

```sh
dart compile js web/main.dart -o web/main.dart.js \
  -DANALYTICS_ENDPOINT=https://analytics.example.com/v1/events \
  -DANALYTICS_SOURCE=my-site
```

If the endpoint or source is missing (local development, tests), `WebAnalytics.create` returns `null`; use your
own "analytics off" implementation then. See [Environments](environments.md).

## Behaviour to know

- `track` never throws and never waits. A failed send is silent.
- The referrer and `utm_*` parameters are read once per page load and sent with the first event.
- When the page is hidden, pending events are sent with `sendBeacon`.
- Do not import `web.dart` in code that also runs on a server. Use your own "analytics off" implementation there.

A complete page is in [`example/site`](../example/site).
