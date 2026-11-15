import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import '../../core/phone/dialer.dart';
import 'shared/severity.dart';
import 'shared/triage_card.dart';

/// One next-step action proposed by the agent.
typedef TriageAction = ({
  String id,
  String label,
  String? icon,
  bool emergency,

  /// When set, tapping opens the phone dialer on that number.
  CallTarget? call,
});

/// Next steps: one primary action and a few secondary ones.
///
/// An action flagged `emergency` is rendered in red whatever its position,
/// so "Appeler les urgences" can never look like a harmless option. A call
/// action is reported to the agent and opens the phone dialer.
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

  /// Reports the action first, so the agent composes "what to do while
  /// waiting" during the call, then opens the dialer.
  Future<void> _tap(BuildContext context, TriageAction action) async {
    onAction(action);
    if (action.call case final target?) await dial(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return TriageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? 'Prochaines étapes', style: textTheme.titleMedium),
          const Gap(16),
          _PrimaryButton(action: primary, onTap: () => _tap(context, primary)),
          for (final action in secondary) ...[
            const Gap(10),
            _SecondaryButton(
              action: action,
              onTap: () => _tap(context, action),
            ),
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
    return FilledButton.icon(
      onPressed: onTap,
      style: action.emergency
          ? FilledButton.styleFrom(
              backgroundColor: AppColors.urgent,
              foregroundColor: Colors.white,
            )
          : null,
      icon: Icon(
        medicalIcon(action.icon, fallback: Icons.arrow_forward_rounded),
        size: 20,
      ),
      label: _Label(action: action),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.action, required this.onTap});

  final TriageAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: action.emergency
          ? OutlinedButton.styleFrom(
              foregroundColor: AppColors.urgent,
              side: BorderSide(color: AppColors.urgent.withValues(alpha: 0.5)),
            )
          : null,
      icon: Icon(
        medicalIcon(action.icon, fallback: Icons.chevron_right_rounded),
        size: 20,
      ),
      label: _Label(action: action),
    );
  }
}

/// Button label, followed by the number for a call action ("· 118").
class _Label extends StatelessWidget {
  const _Label({required this.action});

  final TriageAction action;

  @override
  Widget build(BuildContext context) {
    final number = action.call?.number;
    if (number == null) return Text(action.label);
    return Text.rich(
      TextSpan(
        text: action.label,
        children: [
          TextSpan(
            text: '  ·  $number',
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
