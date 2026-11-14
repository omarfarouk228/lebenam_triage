import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../core/theme/app_colors.dart';
import 'shared/triage_card.dart';

/// A pictogram the agent can show. The agent only sends the name
/// (`"fever"`): the icon and colour stay in Flutter, like [Severity].
enum Picto {
  fever(Icons.thermostat_rounded, AppColors.warning),
  headache(Icons.psychology_rounded, AppColors.brand),
  chestPain(Icons.monitor_heart_rounded, AppColors.urgent),
  breathing(Icons.air_rounded, AppColors.urgent),
  cough(Icons.masks_rounded, AppColors.brand),
  belly(Icons.sick_rounded, AppColors.warning),
  bleeding(Icons.bloodtype_rounded, AppColors.urgent),
  injury(Icons.personal_injury_rounded, AppColors.warning),
  child(Icons.child_care_rounded, AppColors.safe),
  pregnancy(Icons.pregnant_woman_rounded, AppColors.safe),
  tired(Icons.bedtime_rounded, AppColors.brand),
  other(Icons.more_horiz_rounded, AppColors.brand);

  const Picto(this.icon, this.color);

  final IconData icon;
  final Color color;

  /// Names exposed to the LLM, in the order of the enum.
  static const names = [
    'fever',
    'headache',
    'chest_pain',
    'breathing',
    'cough',
    'belly',
    'bleeding',
    'injury',
    'child',
    'pregnancy',
    'tired',
    'other',
  ];

  /// Lenient parsing: an unknown name falls back to [other].
  static Picto parse(Object? raw) {
    final i = names.indexOf('$raw');
    return i < 0 ? Picto.other : Picto.values[i];
  }
}

typedef PictoOption = ({String id, Picto picto, String label});

/// Large pictogram tiles for patients who cannot read.
///
/// One tap answers: no checkbox, no submit button, no sentence to read.
/// The label is a one or two-word caption under the picture, and screen
/// readers announce it.
class PictoChoiceWidget extends StatefulWidget {
  const PictoChoiceWidget({
    super.key,
    required this.options,
    required this.onSelected,
    this.title,
  });

  final String? title;
  final List<PictoOption> options;
  final ValueChanged<PictoOption> onSelected;

  @override
  State<PictoChoiceWidget> createState() => _PictoChoiceWidgetState();
}

class _PictoChoiceWidgetState extends State<PictoChoiceWidget> {
  String? _selected;

  void _tap(PictoOption option) {
    if (_selected != null) return;
    setState(() => _selected = option.id);
    widget.onSelected(option);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TriageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.title != null) ...[
            Text(widget.title!, style: textTheme.titleLarge),
            const Gap(16),
          ],
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              for (final (i, option) in widget.options.indexed)
                _PictoTile(
                      option: option,
                      selected: _selected == option.id,
                      dimmed: _selected != null && _selected != option.id,
                      onTap: () => _tap(option),
                    )
                    .animate(delay: (80 * i).ms)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      duration: 300.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 250.ms),
            ],
          ),
        ],
      ),
    );
  }
}

class _PictoTile extends StatelessWidget {
  const _PictoTile({
    required this.option,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final PictoOption option;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = option.picto.color;
    final radius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.35 : 1,
        child: Material(
          color: color.withValues(alpha: selected ? 0.22 : 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: color.withValues(alpha: selected ? 0.9 : 0.3),
              width: selected ? 3 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(option.picto.icon, size: 64, color: color),
                  const Gap(10),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
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
