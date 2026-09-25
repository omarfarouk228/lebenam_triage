import 'package:shared_preferences/shared_preferences.dart';

/// Where the Gemini API key comes from, in priority order:
///   1. `--dart-define=GEMINI_API_KEY=...` (recommended, never stored)
///   2. a key typed in the setup screen, saved on the device
///
/// For production, don't ship a key in the app: use Firebase AI Logic so the
/// key stays server-side and requests are protected by App Check.
class ApiKeyStore {
  ApiKeyStore._();

  static const _envKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _prefsKey = 'gemini_api_key';

  static String? _key;

  /// The Gemini model; override with `--dart-define=GEMINI_MODEL=...`.
  static const model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static String? get key => _key;
  static bool get hasKey => _key?.isNotEmpty ?? false;
  static bool get isFromEnvironment => _envKey.isNotEmpty;

  /// Loads the key once at startup.
  static Future<void> load() async {
    if (_envKey.isNotEmpty) {
      _key = _envKey;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _key = prefs.getString(_prefsKey);
    } catch (_) {
      // Storage unavailable: the setup screen will simply ask again.
    }
  }

  static Future<void> save(String key) async {
    _key = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _key!);
    } catch (_) {
      // Keep the in-memory key for this session.
    }
  }

  static Future<void> clear() async {
    _key = isFromEnvironment ? _envKey : null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }
}
