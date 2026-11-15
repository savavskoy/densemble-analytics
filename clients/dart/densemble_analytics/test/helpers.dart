import 'dart:async';
import 'dart:convert';

import 'package:densemble_analytics/densemble_analytics.dart';

class FakeTransport implements Transport {
  FakeTransport([this.handler]);
  final FutureOr<void> Function(String body)? handler;
  final List<String> bodies = [];

  @override
  Future<void> send(Uri endpoint, String jsonBody) async {
    bodies.add(jsonBody);
    await handler?.call(jsonBody);
  }

  Map<String, Object?> get last => (jsonDecode(bodies.last) as Map).cast();
}

class FixedContext implements ContextProvider {
  FixedContext([this.value = const EventContext()]);
  EventContext value;
  @override
  EventContext current() => value;
}

final config = AnalyticsConfig(endpoint: Uri.parse('https://example.com/v1/events'), source: 'my-site');
