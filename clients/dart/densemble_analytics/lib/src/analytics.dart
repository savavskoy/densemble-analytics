/// The one interface a host project talks to.
abstract interface class Analytics {
  /// Records [event]. Never throws, never blocks, never awaits the network.
  void track(AnalyticsEvent event);

  /// Completes when events already sent have settled. Completes normally even on failure.
  Future<void> flush();
}

/// [name] must match `^[a-z][a-z0-9_]{0,63}$`, otherwise the event is dropped.
/// [params] is flat: at most 20 keys matching `^[a-z][a-z0-9_]{0,39}$`; values are String
/// (cut to 200 chars), finite num or bool. Do not put personal data in parameters.
class AnalyticsEvent {
  const AnalyticsEvent(this.name, {this.params = const {}});
  final String name;
  final Map<String, Object> params;
}

/// A page or screen was shown. Only the length of [title] is sent, never the text.
class ScreenView extends AnalyticsEvent {
  ScreenView({String? title}) : super('page_view', params: {if (title != null) 'title_len': title.length});
}

class ButtonClick extends AnalyticsEvent {
  ButtonClick(String id) : super('button_click', params: {'id': id});
}

class FormSubmit extends AnalyticsEvent {
  FormSubmit(String id, {bool success = true}) : super('form_submit', params: {'id': id, 'success': success});
}

class NavigationClick extends AnalyticsEvent {
  NavigationClick(String target) : super('navigation_click', params: {'target': target});
}

/// Sends nothing. Used on the server and whenever analytics is not configured.
final class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  void track(AnalyticsEvent event) {}

  @override
  Future<void> flush() async {}
}
