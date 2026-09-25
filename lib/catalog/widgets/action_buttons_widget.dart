import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'shared/severity.dart';
import 'shared/triage_card.dart';

/// One next-step action proposed by the agent.
typedef TriageAction = ({
  String id,
  String label,
  String? icon,
  bool emergency,
});

/// Next steps: one primary action and a few secondary ones.
///
/// An action flagged `emergency` is rendered in red whatever its position,
/// so "Appeler les urgences" can never look like a harmless option.
class ActionButtonsWidget extends StatelessWidget {
  const ActionButtonsWidget({
    super.key,
    required this.primary,
    required this.onAction,
    this.secondary = const [],
    this.title,
  });

  final String? title;
  final TriageAction primary;
  final List<TriageAction> secondary;
  final ValueChanged<TriageAction> onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TriageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? 'Prochaines étapes', style: textTheme.titleMedium),
          const Gap(14),
          _PrimaryButton(action: primary, onTap: () => onAction(primary)),
          for (final action in secondary) ...[
            const Gap(10),
            _SecondaryButton(action: action, onTap: () => onAction(action)),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.action, required this.onTap});

  final TriageAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 58),
        backgroundColor: action.emergency ? AppColors.urgent : scheme.primary,
        foregroundColor: action.emergency ? Colors.white : scheme.onPrimary,
      ),
      icon: Icon(
        medicalIcon(action.icon, fallback: Icons.arrow_forward_rounded),
      ),
      label: Text(action.label),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.action, required this.onTap});

  final TriageAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = action.emergency ? AppColors.urgent : scheme.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      icon: Icon(
        medicalIcon(action.icon, fallback: Icons.chevron_right_rounded),
      ),
      label: Text(action.label),
    );
  }
}
