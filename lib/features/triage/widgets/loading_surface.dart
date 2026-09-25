import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';

/// "AI is thinking" state: a status line and shimmering skeleton cards
/// shaped like the interface about to appear.
///
/// Made to be visible from the back of a conference room: the audience must
/// feel the moment when the agent is composing the next interface.
class LoadingSurface extends StatelessWidget {
  const LoadingSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: "L'IA analyse vos symptômes",
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppColors.brand,
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .rotate(duration: 2400.ms, curve: Curves.easeInOut),
                const Gap(10),
                Text('Analyse en cours', style: textTheme.titleSmall)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fade(begin: 0.45, end: 1, duration: 900.ms),
              ],
            ),
            const Gap(4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                "Gemini compose l'interface adaptée",
                style: textTheme.bodySmall,
              ),
            ),
            const Gap(20),
            const _Skeleton(height: 88),
            const Gap(12),
            const _Skeleton(height: 180),
            const Gap(12),
            const _Skeleton(height: 120),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1500.ms,
          color: scheme.onSurface.withValues(alpha: 0.06),
        );
  }
}
