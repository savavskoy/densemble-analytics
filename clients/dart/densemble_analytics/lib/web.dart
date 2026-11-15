/// Browser entry point. Import only from code that runs in a browser.
///
/// Server-rendered code must build `NoopAnalytics` instead; as a second line,
/// [WebAnalytics.create] returns `NoopAnalytics` without a `window`.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'densemble_analytics.dart';
import 'src/web_logic.dart';

/// `fetch(keepalive)` with a `text/plain` body (no CORS preflight); `navigator.sendBeacon`
/// when the page is hidden or closing.
class WebTransport implements Transport {
  @override
  Future<void> send(Uri endpoint, String jsonBody) async {
    final url = endpoint.toString();
    if (web.document.visibilityState == 'hidden' && web.window.navigator.sendBeacon(url, jsonBody.toJS)) return;
    await web.window
        .fetch(
          url.toJS,
          web.RequestInit(
            method: 'POST',
            body: jsonBody.toJS,
            keepalive: true,
            headers: web.Headers()..append('content-type', 'text/plain;charset=UTF-8'),
          ),
        )
        .toDart;
  }
}

abstract final class WebAnalytics {
  /// Analytics for a page. `NoopAnalytics` without a browser `window`, [endpoint] or [source].
  static Analytics create({Uri? endpoint, String? source}) {
    try {
      if (!globalContext.has('window')) return const NoopAnalytics();
      return DirectAnalytics.create(
        AnalyticsConfig(endpoint: endpoint, source: source),
        transport: WebTransport(),
        context: PageLoadContext(
          pathname: () => web.window.location.pathname,
          language: () => web.window.navigator.language,
          referrer: web.document.referrer,
          search: web.window.location.search,
        ),
      );
    } catch (_) {
      return const NoopAnalytics();
    }
  }
}

/// Single-page navigation: call after the router changed the address.
extension WebPageViews on Analytics {
  void trackPageView({String? title}) => track(ScreenView(title: title ?? web.document.title));
}
