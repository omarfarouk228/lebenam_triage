import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';

/// "AI is thinking" state: pulsing rings + skeleton cards.
///
/// Made to be visible from the back of a conference room: the audience must
/// feel the moment when the agent is composing the next interface.
class LoadingSurface extends StatelessWidget {
  const LoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      label: "L'IA analyse vos symptômes",
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.accent,
                                width: 2,
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .scaleXY(
                            begin: 0.4,
                            end: 1,
                            delay: (i * 500).ms,
                            duration: 1500.ms,
                            curve: Curves.easeOut,
                          )
                          .fadeOut(delay: (i * 500).ms, duration: 1500.ms),
                    Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.5),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(end: 1.08, duration: 800.ms),
                  ],
                ),
              ),
              const Gap(24),
              Text(
                    "L'IA analyse vos symptômes...",
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fade(begin: 0.55, end: 1, duration: 900.ms),
              const Gap(6),
              Text(
                "Gemini compose l'interface adaptée",
                style: theme.textTheme.bodySmall,
              ),
              const Gap(28),
              const _SkeletonCard(height: 72),
              const Gap(12),
              const _SkeletonCard(height: 140),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
          height: height,
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: AppColors.accent.withValues(alpha: 0.25),
        );
  }
}
