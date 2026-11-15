import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'shared/triage_card.dart';

/// Vital signs captured by [VitalInputWidget]. `null` = not measured.
typedef Vitals = ({double? temperatureC, int? heartRateBpm});

/// Numeric capture of vitals: temperature (°C) and, optionally, heart rate.
///
/// Validation is local and immediate (a 60 °C temperature is a typo, not a
/// symptom); only plausible values are sent to the agent.
class VitalInputWidget extends StatefulWidget {
  const VitalInputWidget({
    super.key,
    required this.title,
    required this.onSubmit,
    this.note,
    this.askHeartRate = false,
    this.submitLabel = 'Envoyer les mesures',
  });

  final String title;
  final String? note;
  final bool askHeartRate;
  final String submitLabel;
  final ValueChanged<Vitals> onSubmit;

  @override
  State<VitalInputWidget> createState() => _VitalInputWidgetState();
}

class _VitalInputWidgetState extends State<VitalInputWidget> {
  final _formKey = GlobalKey<FormState>();
  final _temperature = TextEditingController();
  final _heartRate = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _temperature.dispose();
    _heartRate.dispose();
    super.dispose();
  }

  double? _parseTemp(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitted = true);
    widget.onSubmit((
      temperatureC: _parseTemp(_temperature.text),
      heartRateBpm: int.tryParse(_heartRate.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return TriageCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.monitor_heart_outlined,
                  color: AppColors.urgent,
                ),
                const Gap(14),
                Expanded(
                  child: Text(widget.title, style: textTheme.titleMedium),
                ),
              ],
            ),
            if (widget.note != null) ...[
              const Gap(10),
              Text(widget.note!, style: textTheme.bodySmall),
            ],
            const Gap(18),
            _VitalField(
              controller: _temperature,
              enabled: !_submitted,
              label: 'Température',
              unit: '°C',
              hint: '37,5',
              icon: Icons.thermostat_rounded,
              decimal: true,
              validator: (raw) {
                if (raw == null || raw.trim().isEmpty) {
                  return 'Indiquez la température (ou « 0 » si non mesurée)';
                }
                final v = _parseTemp(raw);
                if (v == 0) return null;
                if (v == null || v < 34 || v > 43) {
                  return 'Valeur entre 34 et 43 °C';
                }
                return null;
              },
            ),
            if (widget.askHeartRate) ...[
              const Gap(14),
              _VitalField(
                controller: _heartRate,
                enabled: !_submitted,
                label: 'Fréquence cardiaque (facultatif)',
                unit: 'bpm',
                hint: '80',
                icon: Icons.favorite_rounded,
                validator: (raw) {
                  if (raw == null || raw.trim().isEmpty) return null;
                  final v = int.tryParse(raw.trim());
                  if (v == null || v < 30 || v > 220) {
                    return 'Valeur entre 30 et 220 bpm';
                  }
                  return null;
                },
              ),
            ],
            const Gap(20),
            SubmitButton(
              label: widget.submitLabel,
              doneLabel: 'Mesures envoyées',
              done: _submitted,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _VitalField extends StatelessWidget {
  const _VitalField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.unit,
    required this.hint,
    required this.icon,
    required this.validator,
    this.decimal = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String unit;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
        ),
      ],
      style: textTheme.titleLarge,
      decoration: InputDecoration(
        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: unit,
        suffixStyle: textTheme.titleMedium,
      ),
    );
  }
}
