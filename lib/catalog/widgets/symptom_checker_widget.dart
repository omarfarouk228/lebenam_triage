import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'shared/triage_card.dart';

/// A symptom the agent wants the patient to confirm or deny.
typedef SymptomOption = ({String id, String label});

/// Yes/no checklist of related symptoms, with a progress indicator.
///
/// Toggling is purely local UI state: nothing goes to the agent until the
/// patient taps "Valider". One tap = one LLM round trip, not one per toggle.
class SymptomCheckerWidget extends StatefulWidget {
  const SymptomCheckerWidget({
    super.key,
    required this.title,
    required this.symptoms,
    required this.onSubmit,
    this.question,
    this.submitLabel = 'Valider mes réponses',
  });

  final String title;
  final String? question;
  final List<SymptomOption> symptoms;
  final String submitLabel;

  /// Called with the labels the patient confirmed and those left unchecked.
  final void Function(List<String> confirmed, List<String> denied) onSubmit;

  @override
  State<SymptomCheckerWidget> createState() => _SymptomCheckerWidgetState();
}

class _SymptomCheckerWidgetState extends State<SymptomCheckerWidget> {
  final _selected = <String>{};
  bool _submitted = false;

  void _submit() {
    setState(() => _submitted = true);
    final confirmed = [
      for (final s in widget.symptoms)
        if (_selected.contains(s.id)) s.label,
    ];
    final denied = [
      for (final s in widget.symptoms)
        if (!_selected.contains(s.id)) s.label,
    ];
    widget.onSubmit(confirmed, denied);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final total = widget.symptoms.length;
    final progress = total == 0 ? 0.0 : _selected.length / total;

    return TriageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.checklist_rounded,
                color: theme.colorScheme.primary,
              ),
              const Gap(14),
              Expanded(child: Text(widget.title, style: textTheme.titleMedium)),
              Text(
                '${_selected.length}/$total',
                style: textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (widget.question != null) ...[
            const Gap(10),
            Text(widget.question!, style: textTheme.bodyMedium),
          ],
          const Gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: AppColors.accent,
                backgroundColor: theme.colorScheme.surfaceContainer,
              ),
            ),
          ),
          const Gap(12),
          for (final symptom in widget.symptoms)
            _SymptomTile(
              label: symptom.label,
              selected: _selected.contains(symptom.id),
              enabled: !_submitted,
              onChanged: (value) => setState(() {
                value
                    ? _selected.add(symptom.id)
                    : _selected.remove(symptom.id);
              }),
            ),
          const Gap(12),
          FilledButton.icon(
            onPressed: _submitted ? null : _submit,
            icon: Icon(
              _submitted ? Icons.check_rounded : Icons.send_rounded,
              size: 20,
            ),
            label: Text(_submitted ? 'Réponses envoyées' : widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

class _SymptomTile extends StatelessWidget {
  const _SymptomTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? AppColors.accent
        : theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => onChanged(!selected) : null,
          child: Semantics(
            checked: selected,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Text(
                      selected ? 'Oui' : 'Non',
                      key: ValueKey(selected),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const Gap(8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? AppColors.accent : color,
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
