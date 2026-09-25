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
              const IconBadge(
                icon: Icons.checklist_rounded,
                color: AppColors.brand,
              ),
              const Gap(14),
              Expanded(child: Text(widget.title, style: textTheme.titleMedium)),
              Text('${_selected.length}/$total', style: textTheme.labelMedium),
            ],
          ),
          if (widget.question != null) ...[
            const Gap(10),
            Text(widget.question!, style: textTheme.bodySmall),
          ],
          const Gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: AppColors.brand,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
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
          const Gap(14),
          SubmitButton(
            label: widget.submitLabel,
            doneLabel: 'Réponses envoyées',
            done: _submitted,
            onPressed: _submit,
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? AppColors.brand.withValues(alpha: isDark ? 0.22 : 0.12)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => onChanged(!selected) : null,
          child: Semantics(
            checked: selected,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyLarge),
                  ),
                  const Gap(12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.brand : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.brand
                            : theme.colorScheme.outline.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
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
