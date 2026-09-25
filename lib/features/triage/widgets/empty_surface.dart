import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

/// Empty state shown before the first message: a greeting and a few
/// example sentences the patient (or the speaker) can tap.
class EmptySurface extends StatelessWidget {
  const EmptySurface({
    super.key,
    required this.suggestions,
    required this.onSuggestion,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Comment vous\nsentez-vous ?', style: textTheme.displaySmall)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOutCubic),
              const Gap(12),
              Text(
                "Écrivez ou parlez : l'interface s'adapte à votre situation.",
                style: textTheme.bodyLarge?.copyWith(
                  color: textTheme.bodySmall?.color,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
              const Gap(32),
              Text('Exemples', style: textTheme.labelMedium),
              const Gap(10),
              for (final (i, text) in suggestions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Suggestion(
                    text: text,
                    onTap: () => onSuggestion(text),
                  ),
                ).animate().fadeIn(delay: (200 + 80 * i).ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              const Gap(8),
              Icon(
                Icons.north_west_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
