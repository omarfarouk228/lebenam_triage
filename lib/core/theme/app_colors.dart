import 'package:flutter/material.dart';

/// Brand palette of Lébénam Triage.
///
/// Severity colours (urgent / warning / safe) are identical in light and dark
/// mode on purpose: a red card must mean the same thing everywhere.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF0D4F4F); // deep teal
  static const accent = Color(0xFF4ECDC4); // soft cyan

  // Severity
  static const urgent = Color(0xFFE74C3C);
  static const warning = Color(0xFFF39C12);
  static const safe = Color(0xFF27AE60);

  // Light surfaces
  static const background = Color(0xFFF8FFFE); // near white, teal tint
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0B2E2E);

  // Dark surfaces (derived from the primary teal)
  static const darkBackground = Color(0xFF061717);
  static const darkCard = Color(0xFF0E2626);
  static const darkInk = Color(0xFFE3F6F4);
}
