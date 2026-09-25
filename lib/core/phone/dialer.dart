import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Who a call action reaches. The agent only picks the kind; the numbers
/// live in the app (never invented by the LLM).
enum CallTarget {
  emergency,
  clinic;

  /// Lenient parsing: unknown values → `null` (not a call).
  static CallTarget? parse(Object? raw) => switch (raw) {
    'emergency' || 'urgence' || 'urgences' => CallTarget.emergency,
    'clinic' || 'nurse' || 'doctor' || 'clinique' => CallTarget.clinic,
    _ => null,
  };

  /// Numbers, overridable in .env.json (`EMERGENCY_PHONE`, `CLINIC_PHONE`).
  /// 118: Togo fire and rescue service (ambulance, first aid).
  String? get number => switch (this) {
    CallTarget.emergency => _nonEmpty(
      const String.fromEnvironment('EMERGENCY_PHONE', defaultValue: '118'),
    ),
    CallTarget.clinic => _nonEmpty(
      const String.fromEnvironment('CLINIC_PHONE'),
    ),
  };

  static String? _nonEmpty(String s) => s.trim().isEmpty ? null : s.trim();
}

/// Opens the phone dialer pre-filled with [target]'s number. The patient
/// still presses "call" themselves: no CALL_PHONE permission needed.
Future<void> dial(BuildContext context, CallTarget target) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final number = target.number;
  if (number == null) {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Numéro de la clinique non configuré (CLINIC_PHONE dans .env.json).',
        ),
      ),
    );
    return;
  }
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    // No dialer (tablet, desktop, tests): fall through to the message.
  }
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text("Impossible d'ouvrir le téléphone. Composez le $number."),
      ),
    );
  }
}
