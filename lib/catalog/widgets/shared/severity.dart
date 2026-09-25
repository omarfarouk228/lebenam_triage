import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Severity scale shared by every catalog widget.
///
/// The LLM only ever sends the string (`"info"`, `"low"`, `"moderate"`,
/// `"high"`): the mapping to colours, labels and icons stays in Flutter.
/// The agent decides *what* to say, the app decides *how it looks*.
enum Severity {
  info(AppColors.accent, 'Information', Icons.info_outline_rounded),
  low(AppColors.safe, 'Urgence faible', Icons.check_circle_outline_rounded),
  moderate(AppColors.warning, 'Urgence modérée', Icons.schedule_rounded),
  high(AppColors.urgent, 'Urgence élevée', Icons.emergency_rounded);

  const Severity(this.color, this.label, this.icon);

  final Color color;
  final String label;
  final IconData icon;

  /// Lenient parsing: unknown values fall back to [info] instead of throwing,
  /// so a slightly-off LLM value never breaks the screen.
  static Severity parse(Object? raw) => switch (raw) {
    'low' || 'green' || 'faible' => Severity.low,
    'moderate' || 'medium' || 'orange' || 'modérée' => Severity.moderate,
    'high' || 'red' || 'critical' || 'élevée' => Severity.high,
    _ => Severity.info,
  };
}

/// Medical icon vocabulary exposed to the LLM (see the system prompt).
IconData medicalIcon(String? name, {IconData fallback = Icons.info_outline}) =>
    switch (name) {
      'heart' => Icons.favorite_rounded,
      'medical' || 'cross' => Icons.local_hospital_rounded,
      'thermometer' || 'fever' => Icons.thermostat_rounded,
      'clock' => Icons.schedule_rounded,
      'warning' => Icons.warning_amber_rounded,
      'info' => Icons.info_outline_rounded,
      'water' => Icons.water_drop_rounded,
      'rest' || 'bed' => Icons.bed_rounded,
      'phone' || 'call' => Icons.call_rounded,
      'emergency' || 'ambulance' => Icons.emergency_rounded,
      'clinic' || 'hospital' => Icons.local_hospital_outlined,
      'doctor' => Icons.medical_services_rounded,
      'pill' || 'medication' => Icons.medication_rounded,
      'book' || 'learn' => Icons.menu_book_rounded,
      'hand' || 'empathy' => Icons.volunteer_activism_rounded,
      'lungs' || 'breath' => Icons.air_rounded,
      'brain' || 'head' => Icons.psychology_rounded,
      _ => fallback,
    };
