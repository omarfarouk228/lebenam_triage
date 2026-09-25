import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'shared/triage_card.dart';

/// Values captured by [TriageFormWidget].
typedef TriageFormResult = ({
  int urgency,
  String? duration,
  String? bodyPart,
  List<String> symptoms,
});

/// Structured triage form: felt intensity (1–5), duration, body part and
/// symptom list.
///
/// The agent can pre-fill every field from what the patient already said
/// (`urgency`, `duration`, `bodyPart`, `symptoms`): the patient only corrects,
/// they never start from a blank form.
class TriageFormWidget extends StatefulWidget {
  const TriageFormWidget({
    super.key,
    required this.title,
    required this.onSubmit,
    this.urgency = 3,
    this.duration,
    this.bodyPart,
    this.symptoms = const [],
    this.durationOptions = defaultDurations,
    this.bodyParts = defaultBodyParts,
    this.submitLabel = 'Envoyer',
  });

  static const defaultDurations = [
    "Moins d'un jour",
    '1 à 3 jours',
    '4 à 7 jours',
    "Plus d'une semaine",
  ];

  static const defaultBodyParts = [
    'Tête',
    'Gorge',
    'Poitrine',
    'Ventre',
    'Dos',
    'Bras / jambes',
    'Peau',
    'Tout le corps',
  ];

  final String title;
  final int urgency;
  final String? duration;
  final String? bodyPart;
  final List<String> symptoms;
  final List<String> durationOptions;
  final List<String> bodyParts;
  final String submitLabel;
  final ValueChanged<TriageFormResult> onSubmit;

  @override
  State<TriageFormWidget> createState() => _TriageFormWidgetState();
}

class _TriageFormWidgetState extends State<TriageFormWidget> {
  late double _urgency = widget.urgency.clamp(1, 5).toDouble();
  late String? _duration = widget.duration;
  late String? _bodyPart = widget.bodyPart;
  late final List<String> _symptoms = [...widget.symptoms];
  bool _submitted = false;

  static const _urgencyLabels = [
    'Très léger',
    'Léger',
    'Gênant',
    'Fort',
    'Insupportable',
  ];

  Color get _urgencyColor => switch (_urgency.round()) {
    <= 2 => AppColors.safe,
    3 => AppColors.warning,
    _ => AppColors.urgent,
  };

  void _submit() {
    setState(() => _submitted = true);
    widget.onSubmit((
      urgency: _urgency.round(),
      duration: _duration,
      bodyPart: _bodyPart,
      symptoms: _symptoms,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return TriageCard(
      child: AbsorbPointer(
        absorbing: _submitted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: Icons.assignment_outlined,
                  color: theme.colorScheme.primary,
                ),
                const Gap(14),
                Expanded(
                  child: Text(widget.title, style: textTheme.titleMedium),
                ),
              ],
            ),
            if (_symptoms.isNotEmpty) ...[
              const Gap(18),
              _SectionLabel('Symptômes'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in _symptoms)
                    InputChip(
                      label: Text(s),
                      onDeleted: () => setState(() => _symptoms.remove(s)),
                    ),
                ],
              ),
            ],
            const Gap(18),
            _SectionLabel('Intensité ressentie'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _urgency,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: _urgencyColor,
                    label: _urgencyLabels[_urgency.round() - 1],
                    semanticFormatterCallback: (v) =>
                        _urgencyLabels[v.round() - 1],
                    onChanged: (v) => setState(() => _urgency = v),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _urgencyColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_urgency.round()}',
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            Text(
              _urgencyLabels[_urgency.round() - 1],
              style: textTheme.bodySmall?.copyWith(color: _urgencyColor),
            ),
            const Gap(18),
            _SectionLabel('Depuis combien de temps ?'),
            _ChoiceWrap(
              options: widget.durationOptions,
              selected: _duration,
              onSelected: (v) => setState(() => _duration = v),
            ),
            const Gap(18),
            _SectionLabel('Où avez-vous mal ?'),
            _ChoiceWrap(
              options: widget.bodyParts,
              selected: _bodyPart,
              onSelected: (v) => setState(() => _bodyPart = v),
            ),
            const Gap(20),
            FilledButton.icon(
              onPressed: _submitted ? null : _submit,
              icon: Icon(
                _submitted ? Icons.check_rounded : Icons.send_rounded,
                size: 20,
              ),
              label: Text(_submitted ? 'Envoyé' : widget.submitLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            selectedColor: AppColors.accent.withValues(alpha: 0.25),
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}
