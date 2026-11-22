## 0.2.0

- `DensembleAnalytics` is now one concrete class with `track(name, params:)` and `flush()`
  (was `DirectAnalytics`). Hide it behind your project's own analytics interface.
- Removed the `Analytics` interface, `AnalyticsEvent` and its built-in subclasses, `NoopAnalytics`
  and `AnalyticsConfig`. `create` and `WebAnalytics.create` return `null` when not configured.
- `package:web` constraint widened to `>=1.1.1 <2.0.0`.

## 0.1.0

- First release: web client that sends each event to the collector.
