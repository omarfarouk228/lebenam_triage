import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/api_key_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/brand/lebenam_logo.dart';
import '../../core/theme/theme_controller.dart';
import '../setup/api_key_screen.dart';
import '../triage/triage_screen.dart';

/// Home: brand, one headline and a single call to action.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _start(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) =>
            ApiKeyStore.hasKey ? const TriageScreen() : const ApiKeyScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const LebenamWordmark(height: 24),
                      const Spacer(),
                      const ThemeModeButton(),
                    ],
                  ),
                  const Spacer(flex: 3),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'à portée de voix',
                          style: GoogleFonts.rochester(
                            fontSize: 34,
                            height: 1,
                            color: isDark
                                ? AppColors.brandOrange
                                : AppColors.brandOrangeText,
                          ),
                        ).animate().fadeIn(duration: 600.ms),
                        const Gap(8),
                        Text(
                              'Le triage qui\ns’adapte à vous.',
                              style: textTheme.displaySmall,
                            )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                        const Gap(16),
                        Text(
                          'Décrivez ce que vous ressentez, par écrit ou à voix '
                          "haute. L'IA compose l'écran dont vous avez besoin.",
                          style: textTheme.bodyLarge?.copyWith(
                            color: textTheme.bodySmall?.color,
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 600.ms),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: () => _start(context),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 56),
                          ),
                          child: const Text('Commencer'),
                        ),
                        const Gap(16),
                        Text(
                          'Flutter · GenUI SDK · Gemini · DevFest Afrique 2026',
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ).animate().fadeIn(delay: 300.ms, duration: 600.ms),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
