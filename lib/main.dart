import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';

const String? _appCheckDebugToken = bool.hasEnvironment('APP_CHECK_DEBUG_TOKEN')
    ? String.fromEnvironment('APP_CHECK_DEBUG_TOKEN')
    : null;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the system bars so they take the app's background colour.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check: only the genuine app can call Gemini through Firebase.
  // Release builds prove it with Play Integrity / App Attest. Debug builds
  // use APP_CHECK_DEBUG_TOKEN (.env.json), registered in the Firebase
  // console; it is never read outside debug mode.
  // (Web would need a reCAPTCHA site key: not set up for this demo.)
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider(debugToken: _appCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider(debugToken: _appCheckDebugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
  await ThemeController.instance.load();
  runApp(const LebenamApp());
}
