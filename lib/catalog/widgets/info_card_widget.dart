import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'shared/severity.dart';
import 'shared/triage_card.dart';

/// Informational card: title + body, optional icon, background tinted by
/// severity. The agent opens every answer with one (empathy first).
class InfoCardWidget extends StatelessWidget {
  const InfoCardWidget({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.severity = Severity.info,
  });

  final String title;
  final String body;
  final IconData? icon;
  final Severity severity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '$title. $body',
      child: TriageCard(
        tint: severity.color,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon ?? severity.icon, color: severity.color),
            const Gap(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const Gap(6),
                  Text(
                    body,
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
