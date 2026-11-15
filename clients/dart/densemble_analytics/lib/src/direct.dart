import 'dart:convert';
import 'analytics.dart';

/// How a request body is delivered. Fire-and-forget: failures may throw, [DirectAnalytics]
/// swallows them.
abstract interface class Transport {
  Future<void> send(Uri endpoint, String jsonBody);
}

/// Where the event happened. [DirectAnalytics] reads it for every event.
class EventContext {
  const EventContext({this.path, this.referrer, this.utm = const {}, this.language});
  final String? path;
  final String? referrer;
  final Map<String, String> utm;
  final String? language;

  /// Page path without query and fragment, starting with `/`, at most 300 chars.
  static String? cleanPath(String? raw) {
    if (raw == null) return null;
    var p = raw;
    final cut = p.indexOf(RegExp(r'[?#]'));
    if (cut >= 0) p = p.substring(0, cut);
    if (p.isEmpty) return null;
    if (!p.startsWith('/')) p = '/$p';
    return p.length > 300 ? p.substring(0, 300) : p;
  }
}

abstract interface class ContextProvider {
  EventContext current();
}

/// Endpoint (full address of `POST /v1/events`) and source. A null one means analytics is off.
class AnalyticsConfig {
  const AnalyticsConfig({this.endpoint, this.source});
  final Uri? endpoint;
  final String? source;

  bool get isConfigured => endpoint != null && endpoint!.hasScheme && source != null && _source.hasMatch(source!);
}

final _source = RegExp(r'^[a-z][a-z0-9_-]{1,39}$');
final _name = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
final _key = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

/// Sends each event at once, in its own request. Nothing is kept: a failed send is forgotten.
final class DirectAnalytics implements Analytics {
  DirectAnalytics(AnalyticsConfig config, {required this.transport, required this.context, this.sendTimeout = const Duration(seconds: 10)})
      : _endpoint = config.endpoint!,
        _source = config.source!;

  /// [NoopAnalytics] when [config] has no endpoint or source.
  static Analytics create(AnalyticsConfig config, {required Transport transport, required ContextProvider context}) =>
      config.isConfigured ? DirectAnalytics(config, transport: transport, context: context) : const NoopAnalytics();

  final Transport transport;
  final ContextProvider context;
  final Duration sendTimeout;
  final Uri _endpoint;
  final String _source;
  final Set<Future<void>> _inflight = {};

  @override
  void track(AnalyticsEvent event) {
    try {
      final body = _encode(event);
      if (body == null) return;
      late Future<void> f;
      f = Future<void>(() => transport.send(_endpoint, body))
          .timeout(sendTimeout)
          .catchError((Object _) {})
          .whenComplete(() => _inflight.remove(f));
      _inflight.add(f);
    } catch (_) {
      // never reaches the host
    }
  }

  @override
  Future<void> flush() async {
    try {
      await Future.wait(_inflight.toList());
    } catch (_) {}
  }

  String? _encode(AnalyticsEvent event) {
    final name = event.name;
    if (!_name.hasMatch(name)) return null;
    final ev = <String, Object>{'name': name};
    final params = _cleanParams(event.params);
    if (params.isNotEmpty) ev['params'] = params;
    EventContext c;
    try {
      c = context.current();
    } catch (_) {
      c = const EventContext();
    }
    final path = EventContext.cleanPath(c.path);
    if (path != null) ev['path'] = path;
    final ref = c.referrer;
    if (ref != null && ref.isNotEmpty && ref.length <= 2000) ev['referrer'] = ref;
    final utm = {
      for (final k in const ['source', 'medium', 'campaign'])
        if ((c.utm[k] ?? '').isNotEmpty) k: c.utm[k]!.length > 120 ? c.utm[k]!.substring(0, 120) : c.utm[k]!,
    };
    if (utm.isNotEmpty) ev['utm'] = utm;
    final lang = c.language;
    if (lang != null && lang.isNotEmpty && lang.length <= 20) ev['language'] = lang;
    return jsonEncode({'source': _source, 'events': [ev]});
  }

  static Map<String, Object> _cleanParams(Object? raw) {
    final out = <String, Object>{};
    if (raw is! Map) return out;
    var inspected = 0;
    // Untyped iteration: a hostile map may hold non-String keys. Never recurse into values.
    for (final MapEntry<Object?, Object?> e in raw.entries) {
      if (++inspected > 200 || out.length >= 20) break;
      final k = e.key, v = e.value;
      if (k is! String || !_key.hasMatch(k)) continue;
      if (v is String) {
        out[k] = v.length <= 200 ? v : v.substring(0, _isHigh(v.codeUnitAt(199)) ? 199 : 200);
      } else if (v is bool || (v is num && v.isFinite)) {
        out[k] = v!;
      }
    }
    return out;
  }

  static bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;
}
