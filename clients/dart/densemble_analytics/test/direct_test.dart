import 'dart:async';
import 'dart:collection';

import 'package:densemble_analytics/densemble_analytics.dart';
import 'package:test/test.dart';

import 'helpers.dart';

class _ThrowingToString {
  @override
  String toString() => throw StateError('no');
}

class _NonStringKeys extends MapBase<String, Object> {
  @override
  Object? operator [](Object? key) => 1;
  @override
  void operator []=(String key, Object value) {}
  @override
  void clear() {}
  @override
  Iterable<String> get keys => throw UnimplementedError();
  @override
  Object? remove(Object? key) => null;
  @override
  Iterable<MapEntry<String, Object>> get entries => <MapEntry<Object, Object>>[const MapEntry(1, 'a')].cast();
}

class _BadName extends AnalyticsEvent {
  _BadName() : super('x');
  @override
  String get name => throw StateError('boom');
}

class _BadContext implements ContextProvider {
  @override
  EventContext current() => throw StateError('no');
}

void main() {
  test('wire body has exactly the planned shape', () async {
    final t = FakeTransport();
    final a = DirectAnalytics.create(config,
        transport: t,
        context: FixedContext(const EventContext(
            path: '/p?x=1#f', referrer: 'https://example.org/', utm: {'source': 'a', 'medium': 'b', 'campaign': 'c', 'term': 't'}, language: 'uk')));
    a.track(ButtonClick('cta'));
    await a.flush();
    expect(t.last, {
      'source': 'my-site',
      'events': [
        {
          'name': 'button_click',
          'params': {'id': 'cta'},
          'path': '/p',
          'referrer': 'https://example.org/',
          'utm': {'source': 'a', 'medium': 'b', 'campaign': 'c'},
          'language': 'uk',
        }
      ],
    });
  });

  test('optional fields are left out when empty', () async {
    final t = FakeTransport();
    final a = DirectAnalytics.create(config, transport: t, context: FixedContext());
    a.track(const AnalyticsEvent('ping'));
    await a.flush();
    expect(t.last, {
      'source': 'my-site',
      'events': [
        {'name': 'ping'}
      ]
    });
  });

  test('track returns at once and never throws on hostile input', () async {
    final t = FakeTransport();
    final a = DirectAnalytics.create(config, transport: t, context: FixedContext());
    final cyclic = <String, Object>{};
    cyclic['self'] = cyclic;
    final events = <AnalyticsEvent>[
      _BadName(),
      AnalyticsEvent('ok', params: cyclic),
      AnalyticsEvent('ok', params: {'a': _ThrowingToString()}),
      AnalyticsEvent('ok', params: {'a': 'x' * 5000000}),
      AnalyticsEvent('ok', params: {'a': double.nan, 'b': double.infinity}),
      AnalyticsEvent('ok', params: {for (var i = 0; i < 100000; i++) 'k$i': i}),
      AnalyticsEvent('ok', params: _NonStringKeys()),
      AnalyticsEvent('Bad Name!'),
      AnalyticsEvent('x' * 100000),
    ];
    final clock = Stopwatch()..start();
    for (final e in events) {
      expect(() => a.track(e), returnsNormally);
    }
    expect(clock.elapsedMilliseconds, lessThan(500));
    await a.flush();
    expect(t.bodies, isNotEmpty);
    for (final b in t.bodies) {
      expect(b.length, lessThan(8 * 1024));
    }
    expect((t.last['events'] as List).single, {'name': 'ok', 'params': {for (var i = 0; i < 20; i++) 'k$i': i}}, reason: 'at most 20 params');
  });

  test('throwing context provider does not stop the event', () async {
    final t = FakeTransport();
    DirectAnalytics.create(config, transport: t, context: _BadContext()).track(const AnalyticsEvent('ok'));
    await Future<void>.delayed(Duration.zero);
    expect(t.bodies, hasLength(1));
  });

  test('throwing, failing and hanging transports are invisible', () async {
    for (final handler in <FutureOr<void> Function(String)>[
      (_) => throw StateError('down'),
      (_) => throw const FormatException('HTTP 500'),
      (_) => Completer<void>().future,
    ]) {
      final a = DirectAnalytics(config, transport: FakeTransport(handler), context: FixedContext(), sendTimeout: const Duration(milliseconds: 50));
      final clock = Stopwatch()..start();
      a.track(ScreenView(title: 'Home'));
      expect(clock.elapsedMilliseconds, lessThan(50));
      await a.flush();
    }
  });

  test('null endpoint, null source or bad source gives NoopAnalytics', () {
    final t = FakeTransport();
    final c = FixedContext();
    expect(DirectAnalytics.create(const AnalyticsConfig(source: 'my-site'), transport: t, context: c), isA<NoopAnalytics>());
    expect(DirectAnalytics.create(AnalyticsConfig(endpoint: Uri.parse('https://example.com/v1/events')), transport: t, context: c), isA<NoopAnalytics>());
    expect(DirectAnalytics.create(AnalyticsConfig(endpoint: Uri.parse('https://example.com/v1/events'), source: 'Bad Source'), transport: t, context: c), isA<NoopAnalytics>());
    expect(DirectAnalytics.create(config, transport: t, context: c), isA<DirectAnalytics>());
  });
}
