/// Browser entry point. Import only from code that runs in a browser.
///
/// Server-rendered code must not import it; as a second line, [WebAnalytics.create]
/// returns null without a `window`.
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
  /// The client for a page. Null without a browser `window`, [endpoint] or [source]:
  /// the host project then uses its own "analytics off" implementation.
  static DensembleAnalytics? create({Uri? endpoint, String? source}) {
    try {
      if (!globalContext.has('window')) return null;
      return DensembleAnalytics.create(
        endpoint: endpoint,
        source: source,
        transport: WebTransport(),
        context: PageLoadContext(
          pathname: () => web.window.location.pathname,
          language: () => web.window.navigator.language,
          referrer: web.document.referrer,
          search: web.window.location.search,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Page views. Only the length of the title is sent, never the text.
extension WebPageViews on DensembleAnalytics {
  /// Once per page load; call again after an in-page (single-page) navigation.
  void trackPageView() => track('page_view', params: {'title_len': web.document.title.length});
}
