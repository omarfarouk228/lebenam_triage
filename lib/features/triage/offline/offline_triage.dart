// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE TRIAGE: when the network (or the power) goes, the clinic keeps
// working.
//
// The agent is not the interface: the catalog is. Gemini and this file speak
// the same A2UI protocol to the same CatalogItems, so the Surface, the
// widgets, the events and the Dart guard don't know who answered.
//
// This is a small rules engine, not an AI: it recognises clear keywords and
// alarm signs, and asks with pictograms when it doesn't understand. Phone
// calls still work: GSM is not the internet.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';

import '../../../catalog/catalog_items.dart';
import '../../../catalog/widgets/picto_choice_widget.dart';

/// What the patient just did, as the offline engine sees it.
///
/// A sealed class: the compiler checks that [OfflineTriage.respond] handles
/// every kind of turn.
sealed class OfflineTurn {
  const OfflineTurn();
}

/// Free text typed by the patient.
final class TextTurn extends OfflineTurn {
  const TextTurn(this.text);
  final String text;
}

/// A voice message. Only the on-device model can listen to it: the rules
/// alone ask with pictograms.
final class VoiceTurn extends OfflineTurn {
  const VoiceTurn([this.wav]);
  final Uint8List? wav;
}

/// What the on-device model understood. A closed vocabulary: the model only
/// fills these three fields (JSON Schema enforced by the engine), and Dart
/// checks them again here before any interface is built.
final class Understanding {
  const Understanding({
    required this.symptom,
    required this.alarm,
    required this.notHealth,
    this.summary,
  });

  /// Values of the `symptom` field the model may write.
  static const symptoms = [...Picto.names, notHealthValue];
  static const notHealthValue = 'not_health';

  static const maxSummaryLength = 160;

  /// Null when [json] is not an object with a known `symptom`.
  static Understanding? tryParse(Object? json) {
    if (json is! Map) return null;
    final symptom = json['symptom'];
    if (symptom is! String || !symptoms.contains(symptom)) return null;
    final summary = json['summary'];
    final text = summary is String ? summary.trim() : '';
    return Understanding(
      symptom: Picto.parse(symptom),
      alarm: json['alarm'] == true,
      notHealth: symptom == notHealthValue,
      summary: text.isEmpty || text.length > maxSummaryLength ? null : text,
    );
  }

  final Picto symptom;
  final bool alarm;
  final bool notHealth;

  /// One sentence restating what the patient said, shown to them.
  final String? summary;
}

/// A tap on a catalog widget (`symptoms_confirmed`, `picto_selected`...).
final class InteractionTurn extends OfflineTurn {
  const InteractionTurn(this.name, this.context);
  final String name;
  final Map<String, Object?> context;
}

abstract final class OfflineTriage {
  /// The A2UI answer (createSurface + updateComponents) for [turn].
  static String respond(OfflineTurn turn, String surfaceId) =>
      _surface(surfaceId, switch (turn) {
        TextTurn(:final text) => _fromText(text),
        VoiceTurn() => _pictos(
          'I cannot listen without a network',
          'Tap the picture that matches how you feel.',
        ),
        InteractionTurn(:final name, :final context) => _fromInteraction(
          name,
          context,
        ),
      });

  /// The A2UI answer when the on-device model understood the patient: the
  /// model understands, the rules below still decide and compose.
  static String respondUnderstood(Understanding u, String surfaceId) =>
      _surface(surfaceId, _fromUnderstanding(u));

  static List<Map<String, Object?>> _fromUnderstanding(Understanding u) {
    if (u.notHealth) {
      return [
        _info(
          'I am here for your health',
          'Describe how you feel: fever, pain, cough... I will guide you.',
          icon: 'learn',
        ),
      ];
    }
    final alarm =
        u.alarm || _alarmPictos.contains(Picto.names[u.symptom.index]);
    final components = alarm
        ? _alarm()
        : switch (u.symptom) {
            Picto.child => _childAge(),
            Picto.fever => _fever(),
            Picto.other => _pictos(
              'Show me',
              'I did not understand well. Tap what bothers you.',
            ),
            _ => _verdict(_Level.moderate),
          };
    final summary = u.summary;
    if (summary == null) return components;
    // The patient sees no transcript: the first card says what was heard.
    return [
      {...components.first, 'title': 'I understood', 'body': summary},
      ...components.skip(1),
    ];
  }

  // ── Rules ─────────────────────────────────────────────────────────────────

  // English first; French kept for patients from Togo.
  static const _alarmWords = [
    'chest',
    'breath',
    'faint',
    'unconscious',
    'seizure',
    'convuls',
    'paralys',
    'bleed',
    'blood',
    'stiff neck',
    'confus',
    'poitrine',
    'respir',
    'saign',
    'nuque',
  ];

  static const _alarmPictos = {'chest_pain', 'breathing', 'bleeding'};

  static bool _has(String text, List<String> words) {
    final t = text.toLowerCase();
    return words.any(t.contains);
  }

  static List<Map<String, Object?>> _fromText(String text) {
    if (_has(text, _alarmWords)) return _alarm();
    if (_has(text, ['child', 'baby', 'daughter', 'enfant', 'bébé'])) {
      return _childAge();
    }
    if (_has(text, ['fever', 'fièvre'])) return _fever();
    // Not understood without the model: ask with pictures, not words.
    return _pictos(
      'Show me',
      'Without a network, I understand pictures better. Tap what bothers you.',
    );
  }

  static List<Map<String, Object?>> _fromInteraction(
    String name,
    Map<String, Object?> context,
  ) {
    if (name == TriageEvents.pictoSelected) {
      final id = '${context['id']}';
      if (_alarmPictos.contains(id)) return _alarm();
      if (id == 'child') return _childAge();
      if (id == 'fever') return _fever();
      return _verdict(_Level.moderate);
    }
    if (name == TriageEvents.symptomsConfirmed) {
      final confirmed = '${context['confirmed']}';
      return _has(confirmed, ['neck', 'confusion', 'drows'])
          ? _alarm()
          : _verdict(_Level.moderate);
    }
    if (name == TriageEvents.triageSubmitted) {
      final urgency = (context['urgency'] as num?)?.toInt() ?? 3;
      return _verdict(urgency >= 3 ? _Level.moderate : _Level.low);
    }
    if (name == TriageEvents.vitalsSubmitted) {
      final t = (context['temperatureC'] as num?)?.toDouble() ?? 0;
      return _verdict(t >= 38 ? _Level.moderate : _Level.low);
    }
    if (name.startsWith('child_age')) {
      return name.endsWith('under_3_months')
          ? _alarm()
          : _verdict(_Level.moderate);
    }
    if (name == TriageEvents.actionSelected &&
        context['actionId'] == 'call_emergency') {
      return _waitForHelp();
    }
    return _goToDesk();
  }

  // ── Interfaces, built from the same catalog as Gemini's ───────────────────

  static Map<String, Object?> _info(
    String title,
    String body, {
    String icon = 'hand',
    String severity = 'info',
  }) => {
    'id': 'empathy',
    'component': 'InfoCard',
    'title': title,
    'body': body,
    'icon': icon,
    'severity': severity,
  };

  static List<Map<String, Object?>> _pictos(String title, String body) => [
    _info(title, body),
    {
      'id': 'pictos',
      'component': 'PictoChoice',
      'title': 'Where does it hurt?',
      'options': [
        {'id': 'fever', 'picto': 'fever', 'label': 'Fever'},
        {'id': 'headache', 'picto': 'headache', 'label': 'Head'},
        {'id': 'chest_pain', 'picto': 'chest_pain', 'label': 'Chest'},
        {'id': 'belly', 'picto': 'belly', 'label': 'Belly'},
        {'id': 'child', 'picto': 'child', 'label': 'My child'},
        {'id': 'bleeding', 'picto': 'bleeding', 'label': 'Blood'},
      ],
    },
  ];

  static List<Map<String, Object?>> _alarm() => [
    _info(
      'Stay calm, we are taking care of you',
      'Sit down and do not stay alone.',
      icon: 'heart',
      severity: 'high',
    ),
    {
      'id': 'verdict',
      'component': 'UrgencyCard',
      'level': 'high',
      'title': 'Possible emergency',
      'recommendation': 'Call emergency services now.',
      'waitTime': 'Now',
      'reason': 'This sign needs a health worker right away.',
    },
    _actions(
      'Act now',
      {
        'id': 'call_emergency',
        'label': 'Call emergency services',
        'icon': 'emergency',
        'emergency': true,
        'call': 'emergency',
      },
      [
        {
          'id': 'call_staff',
          'label': 'Alert the nurse',
          'icon': 'doctor',
          'emergency': true,
          'call': 'clinic',
        },
      ],
    ),
  ];

  static List<Map<String, Object?>> _fever() => [
    _info(
      'I am here to help you',
      'Answer a few questions about your fever.',
      icon: 'thermometer',
    ),
    {
      'id': 'checker',
      'component': 'SymptomChecker',
      'title': 'Do you also have…',
      'question': 'Tap what you feel.',
      'symptoms': [
        {'id': 'chills', 'label': 'Chills'},
        {'id': 'vomiting', 'label': 'Vomiting'},
        {'id': 'stiff_neck', 'label': 'A stiff neck'},
        {'id': 'confusion', 'label': 'Confusion or drowsiness'},
      ],
      'submitLabel': 'Send',
    },
  ];

  static List<Map<String, Object?>> _childAge() => [
    _info(
      'Let us take care of your child',
      'In very young children, fever needs more attention.',
    ),
    {
      'id': 'age',
      'component': 'SelectInput',
      'label': 'Child\'s age',
      'placeholder': 'Choose',
      'event': 'child_age',
      'options': [
        {'value': 'under_3_months', 'label': 'Under 3 months'},
        {'value': '3_months_5_years', 'label': '3 months to 5 years'},
        {'value': '5_15_years', 'label': '5 to 15 years'},
      ],
    },
  ];

  static List<Map<String, Object?>> _verdict(_Level level) => [
    _info(
      'Thank you for your answers',
      'Drink water and rest in the meantime.',
      icon: 'water',
      severity: level.name,
    ),
    {
      'id': 'verdict',
      'component': 'UrgencyCard',
      'level': level.name,
      'title': level.title,
      'recommendation': level.recommendation,
      'waitTime': level.waitTime,
    },
    _actions(
      'What would you like to do?',
      {'id': 'go_to_clinic', 'label': 'Go to the front desk', 'icon': 'clinic'},
      [
        {
          'id': 'call_nurse',
          'label': 'Call a nurse',
          'icon': 'phone',
          'call': 'clinic',
        },
      ],
    ),
  ];

  static List<Map<String, Object?>> _waitForHelp() => [
    _info(
      'Help has been alerted',
      'You did the right thing by calling. Follow these steps.',
      icon: 'heart',
      severity: 'high',
    ),
    {
      'id': 'steps',
      'component': 'ListCard',
      'title': 'While you wait for help',
      'items': [
        {'title': 'Sit down', 'subtitle': 'Without any effort.'},
        {'title': 'Do not stay alone', 'subtitle': 'Call someone close.'},
        {'title': 'Keep your phone', 'subtitle': 'They may call back.'},
      ],
    },
  ];

  static List<Map<String, Object?>> _goToDesk() => [
    _info(
      'Go to the front desk',
      'Without a network, the nurse will finish your sheet with you.',
      icon: 'clinic',
    ),
  ];

  static Map<String, Object?> _actions(
    String title,
    Map<String, Object?> primary,
    List<Map<String, Object?>> secondary,
  ) => {
    'id': 'actions',
    'component': 'ActionButtons',
    'title': title,
    'primary': primary,
    'secondary': secondary,
  };

  // ── A2UI envelope ─────────────────────────────────────────────────────────

  static String _surface(String id, List<Map<String, Object?>> components) {
    final create = {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': id,
        'catalogId': triageCatalogId,
        'sendDataModel': true,
      },
    };
    final update = {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': id,
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'spacing': 16,
            'children': [for (final c in components) c['id']],
          },
          ...components,
        ],
      },
    };
    return '```json\n${jsonEncode(create)}\n```\n'
        '```json\n${jsonEncode(update)}\n```\n';
  }
}

enum _Level {
  low(
    'Home care',
    'Rest. See a nurse within 48 h if it continues.',
    'Within 48 h',
  ),
  moderate(
    'See a nurse today',
    'Come to the front desk today. You will get a malaria test if you have a fever.',
    '30 to 60 min',
  );

  const _Level(this.title, this.recommendation, this.waitTime);

  final String title;
  final String recommendation;
  final String waitTime;
}
