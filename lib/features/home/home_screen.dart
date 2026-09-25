import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../core/config/api_key_store.dart';
import '../../core/theme/app_colors.dart';
import '../setup/api_key_screen.dart';
import '../triage/triage_screen.dart';

/// Splash / home: brand, tagline and a single call to action.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _start(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
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

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, Color(0xFF0A3B3B), Color(0xFF062626)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const _Logo()
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .scaleXY(begin: 0.8, curve: Curves.easeOutBack),
                    const Gap(32),
                    Text(
                          'Lébénam Triage',
                          style: textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 600.ms)
                        .slideY(begin: 0.2),
                    const Gap(12),
                    Text(
                          'Soins intelligents, interface adaptée',
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        )
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideY(begin: 0.2),
                    const Gap(16),
                    Text(
                      "Décrivez ce que vous ressentez : l'intelligence artificielle "
                      'compose l’écran dont vous avez besoin.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    const Spacer(flex: 4),
                    SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _start(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(0, 60),
                            ),
                            icon: const Icon(Icons.chat_rounded),
                            label: const Text('Décrire vos symptômes'),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 800.ms, duration: 600.ms)
                        .slideY(begin: 0.4),
                    const Gap(20),
                    Text(
                      'Flutter · GenUI SDK · Gemini — DevFest Afrique 2026',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ).animate().fadeIn(delay: 1000.ms, duration: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(end: 1.12, duration: 1600.ms, curve: Curves.easeInOut),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            size: 52,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
