import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import 'shared/severity.dart';
import 'shared/triage_card.dart';

/// Triage verdict: colour-coded urgency (green / orange / red), recommended
/// action and estimated wait time.
///
/// This is the card the audience must read from the back of the room: a
/// solid status pill, a large title and a level meter. When urgent, the
/// pill's dot pulses.
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final color = severity.color;

    return Semantics(
      container: true,
      liveRegion: true,
      label: '${severity.label}. $title. $recommendation',
      child: TriageCard(
        tint: color,
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusPill(severity: severity),
                const Spacer(),
                _LevelMeter(severity: severity),
              ],
            ),
            const Gap(16),
            Text(title, style: textTheme.headlineSmall),
            const Gap(18),
            Divider(color: color.withValues(alpha: 0.25)),
            const Gap(16),
            _InfoRow(label: 'Action recommandée', value: recommendation),
            if (waitTime != null) ...[
              const Gap(14),
              _InfoRow(label: 'Délai de prise en charge', value: waitTime!),
            ],
            if (reason != null) ...[
              const Gap(16),
              Text(reason!, style: textTheme.bodySmall?.copyWith(height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.severity});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
    if (severity == Severity.high) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 1, end: 0.25, duration: 600.ms);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: ShapeDecoration(
        color: severity.color,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const Gap(8),
          Text(
            severity.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three bars showing the level at a glance (1 = low … 3 = high).
class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.severity});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final level = switch (severity) {
      Severity.low => 1,
      Severity.moderate => 2,
      Severity.high => 3,
      Severity.info => 0,
    };
    final off = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(left: 3),
            width: 5,
            height: 8.0 + i * 5,
            decoration: BoxDecoration(
              color: i < level ? severity.color : off,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const Gap(3),
        Text(value, style: textTheme.titleMedium),
      ],
    );
  }
}
