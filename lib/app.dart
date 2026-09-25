import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class LebenamApp extends StatelessWidget {
  const LebenamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lébénam Triage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
