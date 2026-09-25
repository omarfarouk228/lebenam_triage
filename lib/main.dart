import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/api_key_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiKeyStore.load();
  runApp(const LebenamApp());
}
