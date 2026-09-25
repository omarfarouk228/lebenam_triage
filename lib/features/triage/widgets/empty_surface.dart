import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';

/// Empty state shown before the first message.
class EmptySurface extends StatelessWidget {
  const EmptySurface({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.string(
                  _illustration(
                    bubble: isDark ? '#123030' : '#E6F7F5',
                    stroke: isDark ? '#4ECDC4' : '#0D4F4F',
                  ),
                  width: 160,
                  height: 160,
                  excludeFromSemantics: true,
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0,
                  end: -8,
                  duration: 2.seconds,
                  curve: Curves.easeInOut,
                ),
            const Gap(20),
            Text(
              'Commencez par décrire comment vous vous sentez',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              "L'interface s'adaptera à votre situation.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.7,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  /// A speech bubble holding a heart with a pulse line.
  static String _illustration({
    required String bubble,
    required String stroke,
  }) {
    const accent = '#4ECDC4';
    final urgent =
        '#${AppColors.urgent.toARGB32().toRadixString(16).substring(2)}';
    return '''
<svg viewBox="0 0 160 160" xmlns="http://www.w3.org/2000/svg">
  <circle cx="80" cy="80" r="74" fill="$accent" fill-opacity="0.12"/>
  <path d="M40 46h80a14 14 0 0 1 14 14v38a14 14 0 0 1-14 14H74l-20 16v-16H40a14 14 0 0 1-14-14V60a14 14 0 0 1 14-14z"
        fill="$bubble" stroke="$stroke" stroke-width="3" stroke-linejoin="round"/>
  <path d="M80 98c-14-10-22-17-22-26a10 10 0 0 1 22-5 10 10 0 0 1 22 5c0 9-8 16-22 26z"
        fill="$urgent" fill-opacity="0.9"/>
  <polyline points="50,80 64,80 70,70 78,90 84,76 90,80 110,80"
            fill="none" stroke="$accent" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="126" cy="36" r="6" fill="$accent"/>
  <circle cx="140" cy="54" r="3.5" fill="$accent" fill-opacity="0.6"/>
</svg>''';
  }
}
