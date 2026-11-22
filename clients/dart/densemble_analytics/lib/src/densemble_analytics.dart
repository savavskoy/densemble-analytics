import 'dart:async';
import 'dart:convert';

/// How a request body is delivered. Fire-and-forget: failures may throw, [DensembleAnalytics]
/// swallows them.
abstract interface class Transport {
  Future<void> send(Uri endpoint, String jsonBody);
}

/// Where the event happened. [DensembleAnalytics] reads it for every event.
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

final _source = RegExp(r'^[a-z][a-z0-9_-]{1,39}$');
final _name = RegExp(r'^[a-z][a-z0-9_]{0,63}$');
final _key = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

/// The Densemble Analytics client: sends each event at once, in its own request, to the
/// collector's `POST /v1/events`. Nothing is kept: a failed send is forgotten.
///
/// A concrete class, not an interface. Hide it behind your project's own analytics
/// interface, so the rest of the project does not depend on this package.
final class DensembleAnalytics {
  /// [endpoint] is the full address of `POST /v1/events`; [source] names the site or app.
  /// Throws [ArgumentError] when either is invalid; [create] returns null instead.
  DensembleAnalytics({
    required Uri endpoint,
    required String source,
    required this.transport,
    required this.context,
    this.sendTimeout = const Duration(seconds: 10),
  }) : _endpoint = endpoint,
       _sourceName = source {
    if (!isValidConfig(endpoint: endpoint, source: source)) {
      throw ArgumentError('endpoint must be absolute and source must match ${_source.pattern}');
    }
  }

  /// Null when [endpoint] or [source] is missing or invalid: analytics is off.
  static DensembleAnalytics? create({
    Uri? endpoint,
    String? source,
    required Transport transport,
    required ContextProvider context,
  }) => isValidConfig(endpoint: endpoint, source: source)
      ? DensembleAnalytics(endpoint: endpoint!, source: source!, transport: transport, context: context)
      : null;

  static bool isValidConfig({Uri? endpoint, String? source}) =>
      endpoint != null && endpoint.hasScheme && source != null && _source.hasMatch(source);

  final Transport transport;
  final ContextProvider context;
  final Duration sendTimeout;
  final Uri _endpoint;
  final String _sourceName;
  final Set<Future<void>> _inflight = {};

  /// Records an event. Never throws, never blocks, never awaits the network.
  ///
  /// [name] must match `^[a-z][a-z0-9_]{0,63}$`, otherwise the event is dropped.
  /// [params] is flat: at most 20 keys matching `^[a-z][a-z0-9_]{0,39}$`; values are String
  /// (cut to 200 chars), finite num or bool. Do not put personal data in parameters.
  void track(String name, {Map<String, Object> params = const {}}) {
    try {
      final body = _encode(name, params);
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

  /// Completes when events already sent have settled. Completes normally even on failure.
  Future<void> flush() async {
    try {
      await Future.wait(_inflight.toList());
    } catch (_) {}
  }

  String? _encode(String name, Map<String, Object> rawParams) {
    if (!_name.hasMatch(name)) return null;
    final ev = <String, Object>{'name': name};
    final params = _cleanParams(rawParams);
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
    return jsonEncode({
      'source': _sourceName,
      'events': [ev],
    });
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
