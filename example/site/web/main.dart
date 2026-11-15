// The smallest page that reports to Densemble Analytics.
//
// Build:  dart compile js web/main.dart -o web/main.dart.js \
//           -DANALYTICS_ENDPOINT=https://analytics.example.com/v1/events
//
// Server-side rendering: this library imports package:densemble_analytics/web.dart, so it must
// only be compiled into browser code. Code that also runs on a server must not import it; use
// `const NoopAnalytics()` there. WebAnalytics.create also returns NoopAnalytics when there is no
// `window`, endpoint or source, so an unconfigured build is safe and silent.
import 'dart:js_interop';

import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';
import 'package:web/web.dart' as web;

void main() {
  final analytics = WebAnalytics.create(
    endpoint: const bool.hasEnvironment('ANALYTICS_ENDPOINT') ? Uri.parse(const String.fromEnvironment('ANALYTICS_ENDPOINT')) : null,
    source: 'my-site',
  );

  analytics.trackPageView(); // call again after each in-page navigation

  void on(String selector, String type, void Function(web.Event) handler) =>
      web.document.querySelector(selector)?.addEventListener(type, handler.toJS);

  on('#cta', 'click', (_) => analytics.track(ButtonClick('cta')));
  on('#signup', 'submit', (e) {
    e.preventDefault();
    analytics.track(FormSubmit('signup')); // never put the e-mail address into an event
  });
  on('#custom', 'click', (_) {
    // Your own event: name matching ^[a-z][a-z0-9_]{0,63}$, flat scalar parameters.
    analytics.track(const AnalyticsEvent('video_played', params: {'seconds': 12, 'autoplay': false}));
  });
}
