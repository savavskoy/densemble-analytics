@TestOn('browser')
library;

import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';
import 'package:test/test.dart';

void main() {
  test('unconfigured gives NoopAnalytics', () {
    expect(WebAnalytics.create(), isA<NoopAnalytics>());
    expect(WebAnalytics.create(source: 'my-site'), isA<NoopAnalytics>());
  });

  test('unreachable host: nothing throws', () async {
    final a = WebAnalytics.create(endpoint: Uri.parse('https://example.invalid/v1/events'), source: 'my-site');
    expect(a, isA<DirectAnalytics>());
    a.track(ButtonClick('x'));
    a.trackPageView();
    await a.flush();
  });
}
