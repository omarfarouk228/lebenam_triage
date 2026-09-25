import 'package:flutter/material.dart';

/// Palette of Lébénam Triage, taken from the Lébénam brand (see
/// lebenam-landing-next/app/globals.css): cream backgrounds, navy text, blue
/// actions, orange accents, plus the three severity colours.
///
/// Severity colours (urgent / warning / safe) are identical in light and dark
/// mode on purpose: a red card must mean the same thing everywhere.
abstract final class AppColors {
  // Brand
  static const brand = Color(0xFF2171EC); // blue: actions, backgrounds
  static const brandDark = Color(0xFF1C60C9);
  static const brandOrange = Color(0xFFF96000); // logo, focus
  /// Orange for text on light backgrounds (brand orange fails WCAG there).
  static const brandOrangeText = Color(0xFFB84200);
  static const navy = Color(0xFF212645);
  static const navyDark = Color(0xFF1A1E38);
  static const cream = Color(0xFFF7F1E7);
  static const creamLight = Color(0xFFFCF8F0);

  // Severity
  static const urgent = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9500);
  static const safe = Color(0xFF34C759);

  // Light: cream paper, navy ink
  static const lightBackground = cream;
  static const lightSurface = creamLight;
  static const lightSurfaceHigh = Color(0xFFEDE5D6);
  static const lightHairline = Color(0xFFE4DACA);
  static const lightInk = navy;
  static const lightInkMuted = Color(0xFF63667D);

  // Dark: navy night, cream ink
  static const darkBackground = Color(0xFF14172B);
  static const darkSurface = navyDark;
  static const darkSurfaceHigh = navy;
  static const darkHairline = Color(0xFF2C3254);
  static const darkInk = cream;
  static const darkInkMuted = Color(0xFFA6A4AE);
}
