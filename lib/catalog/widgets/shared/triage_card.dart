import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Visual shell shared by all catalog widgets: a flat surface with a
/// hairline border and large radii, optionally washed with a severity
/// colour.
class TriageCard extends StatelessWidget {
  const TriageCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;

  /// When set, the card background is lightly washed with this colour.
  final Color? tint;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerLow;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint == null
            ? base
            : Color.alphaBlend(
                tint!.withValues(alpha: isDark ? 0.14 : 0.07),
                base,
              ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color:
              tint?.withValues(alpha: 0.3) ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Rounded-square tinted badge holding an icon, used as a card leading
/// element.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Full-width primary button with a "sent" state, shared by the forms.
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.done,
    required this.onPressed,
  });

  final String label;
  final String doneLabel;
  final bool done;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: done ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: done
            ? Row(
                key: const ValueKey('done'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(doneLabel),
                ],
              )
            : Text(label, key: const ValueKey('idle')),
      ),
    );
  }
}
