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

class _BadContext implements ContextProvider {
  @override
  EventContext current() => throw StateError('no');
}

void main() {
  test('wire body has exactly the planned shape', () async {
    final t = FakeTransport();
    final a = client(
      t,
      FixedContext(
        const EventContext(
          path: '/p?x=1#f',
          referrer: 'https://example.org/',
          utm: {'source': 'a', 'medium': 'b', 'campaign': 'c', 'term': 't'},
          language: 'uk',
        ),
      ),
    );
    a.track('button_click', params: {'id': 'cta'});
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
        },
      ],
    });
  });

  test('optional fields are left out when empty', () async {
    final t = FakeTransport();
    final a = client(t);
    a.track('ping');
    await a.flush();
    expect(t.last, {
      'source': 'my-site',
      'events': [
        {'name': 'ping'},
      ],
    });
  });

  test('track returns at once and never throws on hostile input', () async {
    final t = FakeTransport();
    final a = client(t);
    final cyclic = <String, Object>{};
    cyclic['self'] = cyclic;
    final events = <(String, Map<String, Object>)>[
      ('ok', cyclic),
      ('ok', {'a': _ThrowingToString()}),
      ('ok', {'a': 'x' * 5000000}),
      ('ok', {'a': double.nan, 'b': double.infinity}),
      ('ok', {for (var i = 0; i < 100000; i++) 'k$i': i}),
      ('ok', _NonStringKeys()),
      ('Bad Name!', const {}),
      ('x' * 100000, const {}),
    ];
    final clock = Stopwatch()..start();
    for (final (name, params) in events) {
      expect(() => a.track(name, params: params), returnsNormally);
    }
    expect(clock.elapsedMilliseconds, lessThan(500));
    await a.flush();
    expect(t.bodies, isNotEmpty);
    for (final b in t.bodies) {
      expect(b.length, lessThan(8 * 1024));
    }
    expect((t.last['events'] as List).single, {
      'name': 'ok',
      'params': {for (var i = 0; i < 20; i++) 'k$i': i},
    }, reason: 'at most 20 params');
  });

  test('throwing context provider does not stop the event', () async {
    final t = FakeTransport();
    client(t, _BadContext()).track('ok');
    await Future<void>.delayed(Duration.zero);
    expect(t.bodies, hasLength(1));
  });

  test('throwing, failing and hanging transports are invisible', () async {
    for (final handler in <FutureOr<void> Function(String)>[
      (_) => throw StateError('down'),
      (_) => throw const FormatException('HTTP 500'),
      (_) => Completer<void>().future,
    ]) {
      final a = DensembleAnalytics(
        endpoint: endpoint,
        source: 'my-site',
        transport: FakeTransport(handler),
        context: FixedContext(),
        sendTimeout: const Duration(milliseconds: 50),
      );
      final clock = Stopwatch()..start();
      a.track('page_view');
      expect(clock.elapsedMilliseconds, lessThan(50));
      await a.flush();
    }
  });

  test('missing or invalid endpoint or source gives null from create and an error from the constructor', () {
    final t = FakeTransport();
    final c = FixedContext();
    expect(DensembleAnalytics.create(source: 'my-site', transport: t, context: c), isNull);
    expect(DensembleAnalytics.create(endpoint: endpoint, transport: t, context: c), isNull);
    expect(DensembleAnalytics.create(endpoint: endpoint, source: 'Bad Source', transport: t, context: c), isNull);
    expect(
      DensembleAnalytics.create(endpoint: Uri.parse('/v1/events'), source: 'my-site', transport: t, context: c),
      isNull,
    );
    expect(
      DensembleAnalytics.create(endpoint: endpoint, source: 'my-site', transport: t, context: c),
      isA<DensembleAnalytics>(),
    );
    expect(
      () => DensembleAnalytics(endpoint: endpoint, source: 'Bad Source', transport: t, context: c),
      throwsArgumentError,
    );
  });
}
