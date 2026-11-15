import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / system preference, saved on the device.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);

  static final instance = ThemeController._();

  static const _prefsKey = 'theme_mode';

  /// Loads the saved preference once at startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Storage unavailable: follow the system.
    }
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {}
  }
}

/// App bar button to pick light, dark or system appearance.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  static const _options = [
    (ThemeMode.system, 'Système', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Clair', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Sombre', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
        tooltip: 'Apparence',
        initialValue: mode,
        onSelected: controller.set,
        icon: Icon(_options.firstWhere((o) => o.$1 == mode).$3),
        itemBuilder: (_) => [
          for (final (value, label, icon) in _options)
            PopupMenuItem(
              value: value,
              child: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label)),
                  if (value == mode) const Icon(Icons.check_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
