/// Gemini settings. There is no API key here, on purpose: requests go
/// through Firebase AI Logic, which keeps the key server-side, and App Check
/// proves they come from this app.
abstract final class GeminiConfig {
  /// The Gemini model; override with `--dart-define=GEMINI_MODEL=...`.
  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );
}
