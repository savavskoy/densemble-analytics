@TestOn('browser')
library;

import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:densemble_analytics/web.dart';
import 'package:test/test.dart';

void main() {
  test('unconfigured gives null', () {
    expect(WebAnalytics.create(), isNull);
    expect(WebAnalytics.create(source: 'my-site'), isNull);
  });

  test('unreachable host: nothing throws', () async {
    final a = WebAnalytics.create(endpoint: Uri.parse('https://example.invalid/v1/events'), source: 'my-site');
    expect(a, isA<DensembleAnalytics>());
    a!.track('button_click', params: {'id': 'x'});
    a.trackPageView();
    await a.flush();
  });
}
