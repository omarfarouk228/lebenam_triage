import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import 'shared/severity.dart';
import 'shared/triage_card.dart';

/// Triage verdict: colour-coded urgency (green / orange / red), recommended
/// action and estimated wait time.
///
/// This is the card the audience must read from the back of the room, so it
/// is deliberately loud: full-colour header and a pulsing icon when urgent.
class UrgencyCardWidget extends StatelessWidget {
  const UrgencyCardWidget({
    super.key,
    required this.severity,
    required this.title,
    required this.recommendation,
    this.waitTime,
    this.reason,
  });

  final Severity severity;
  final String title;
  final String recommendation;
  final String? waitTime;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = severity.color;
    final isHigh = severity == Severity.high;

    Widget headerIcon = Icon(severity.icon, color: Colors.white, size: 30);
    if (isHigh) {
      headerIcon = headerIcon
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(end: 1.18, duration: 700.ms, curve: Curves.easeInOut);
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${severity.label}. $title. $recommendation',
      child: TriageCard(
        tint: color,
        borderColor: color.withValues(alpha: 0.6),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coloured header band
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  headerIcon,
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          severity.label.toUpperCase(),
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _LevelDots(severity: severity),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.local_hospital_rounded,
                    color: color,
                    label: 'Action recommandée',
                    value: recommendation,
                  ),
                  if (waitTime != null) ...[
                    const Gap(14),
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      color: color,
                      label: 'Délai de prise en charge',
                      value: waitTime!,
                    ),
                  ],
                  if (reason != null) ...[
                    const Gap(14),
                    Text(
                      reason!,
                      style: textTheme.bodySmall?.copyWith(
                        color: textTheme.bodySmall?.color?.withValues(
                          alpha: 0.75,
                        ),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots showing the level at a glance (1 = low … 3 = high).
class _LevelDots extends StatelessWidget {
  const _LevelDots({required this.severity});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final level = switch (severity) {
      Severity.low => 1,
      Severity.moderate => 2,
      Severity.high => 3,
      Severity.info => 0,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.only(left: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: i < level ? 1 : 0.3),
          ),
        );
      }),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconBadge(icon: icon, color: color, size: 36),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.labelMedium),
              const Gap(2),
              Text(
                value,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
