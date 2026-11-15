import 'direct.dart';

/// The `utm_source`, `utm_medium` and `utm_campaign` marks of an address query.
Map<String, String> parseUtm(String? search) {
  final out = <String, String>{};
  if (search == null || search.isEmpty) return out;
  var q = search.startsWith('?') ? search.substring(1) : search;
  final hash = q.indexOf('#');
  if (hash >= 0) q = q.substring(0, hash);
  Map<String, String> params;
  try {
    params = Uri.splitQueryString(q);
  } catch (_) {
    return out;
  }
  for (final k in const ['source', 'medium', 'campaign']) {
    final v = params['utm_$k'];
    if (v != null && v.isNotEmpty) out[k] = v.length > 120 ? v.substring(0, 120) : v;
  }
  return out;
}

/// Page context. Referrer and utm are read once, at creation, and go out with the first event
/// of the page load only; the path and language are read on every event.
class PageLoadContext implements ContextProvider {
  PageLoadContext({required this.pathname, required this.language, this.referrer, String? search}) : _utm = parseUtm(search);

  final String? Function() pathname;
  final String? Function() language;
  String? referrer;
  Map<String, String> _utm;

  @override
  EventContext current() {
    final c = EventContext(path: EventContext.cleanPath(pathname()) ?? '/', referrer: referrer, utm: _utm, language: language());
    referrer = null;
    _utm = const {};
    return c;
  }
}
