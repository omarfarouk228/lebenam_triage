import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Visual shell shared by all catalog widgets: card colour, 16px radius,
/// soft shadow and an optional tinted background.
class TriageCard extends StatelessWidget {
  const TriageCard({
    super.key,
    required this.child,
    this.tint,
    this.borderColor,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;

  /// When set, the card background is lightly tinted with this colour.
  final Color? tint;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerLowest;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint == null
            ? base
            : Color.alphaBlend(
                tint!.withValues(alpha: isDark ? 0.16 : 0.08),
                base,
              ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color:
              borderColor ??
              (tint?.withValues(alpha: 0.35) ??
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        boxShadow: AppTheme.cardShadow(theme.brightness),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Round tinted badge holding an icon, used as a card leading element.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
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
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}
