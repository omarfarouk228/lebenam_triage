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
          'Je ne peux pas écouter sans réseau',
          'Touchez l\'image qui correspond à ce que vous ressentez.',
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
          'Je suis là pour votre santé',
          'Décrivez ce que vous ressentez : fièvre, douleur, toux... '
              'Je vous oriente.',
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
              'Montrez-moi',
              'Je n\'ai pas bien compris. Touchez ce qui vous gêne.',
            ),
            _ => _verdict(_Level.moderate),
          };
    final summary = u.summary;
    if (summary == null) return components;
    // The patient sees no transcript: the first card says what was heard.
    return [
      {...components.first, 'title': 'J\'ai compris', 'body': summary},
      ...components.skip(1),
    ];
  }

  // ── Rules ─────────────────────────────────────────────────────────────────

  // Keywords are written without accents: [_fold] strips them from the
  // patient's text, so "fièvre" and "fievre" both match.
  static const _alarmWords = [
    'poitrine',
    'thorax',
    'thoraci',
    'respir',
    'etouff',
    'essouffl',
    'evanoui',
    'inconscient',
    'connaissance',
    'convuls',
    'paralys',
    'saign',
    'sang',
    'nuque',
    'confus',
  ];
  static const _childWords = [
    'enfant',
    'bebe',
    'nourrisson',
    'mon fils',
    'ma fille',
  ];
  static const _feverWords = ['fievre', 'corps chaud', 'temperature', 'palu'];

  static const _alarmPictos = {'chest_pain', 'breathing', 'bleeding'};

  static const _accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'œ': 'oe',
  };

  /// Lower case, without accents (precomposed or combining).
  static String _fold(String text) => text
      .toLowerCase()
      .replaceAllMapped(RegExp('[àâäçéèêëîïôöùûüœ]'), (m) => _accents[m[0]]!)
      .replaceAll(RegExp('[\u0300-\u036f]'), '');

  static bool _has(String text, List<String> words) {
    final t = _fold(text);
    return words.any(t.contains);
  }

  static List<Map<String, Object?>> _fromText(String text) {
    if (_has(text, _alarmWords)) return _alarm();
    if (_has(text, _childWords)) return _childAge();
    if (_has(text, _feverWords)) return _fever();
    // Not understood without the model: ask with pictures, not words.
    return _pictos(
      'Montrez-moi',
      'Sans réseau, je comprends mieux les images. Touchez ce qui vous gêne.',
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
      return _has(confirmed, ['nuque', 'confus', 'somnol'])
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
      'title': 'Où avez-vous mal ?',
      'options': [
        {'id': 'fever', 'picto': 'fever', 'label': 'Fièvre'},
        {'id': 'headache', 'picto': 'headache', 'label': 'Tête'},
        {'id': 'chest_pain', 'picto': 'chest_pain', 'label': 'Poitrine'},
        {'id': 'belly', 'picto': 'belly', 'label': 'Ventre'},
        {'id': 'child', 'picto': 'child', 'label': 'Mon enfant'},
        {'id': 'bleeding', 'picto': 'bleeding', 'label': 'Sang'},
      ],
    },
  ];

  static List<Map<String, Object?>> _alarm() => [
    _info(
      'Restez calme, on s\'occupe de vous',
      'Asseyez-vous et ne restez pas seul.',
      icon: 'heart',
      severity: 'high',
    ),
    {
      'id': 'verdict',
      'component': 'UrgencyCard',
      'level': 'high',
      'title': 'Urgence possible',
      'recommendation': 'Appelez les urgences maintenant.',
      'waitTime': 'Immédiat',
      'reason': 'Ce signe demande un soignant tout de suite.',
    },
    _actions(
      'Agissez maintenant',
      {
        'id': 'call_emergency',
        'label': 'Appeler les urgences',
        'icon': 'emergency',
        'emergency': true,
        'call': 'emergency',
      },
      [
        {
          'id': 'call_staff',
          'label': 'Prévenir l\'infirmier',
          'icon': 'doctor',
          'emergency': true,
          'call': 'clinic',
        },
      ],
    ),
  ];

  static List<Map<String, Object?>> _fever() => [
    _info(
      'Je suis là pour vous aider',
      'Répondez à quelques questions sur votre fièvre.',
      icon: 'thermometer',
    ),
    {
      'id': 'checker',
      'component': 'SymptomChecker',
      'title': 'Avez-vous aussi…',
      'question': 'Touchez ce que vous ressentez.',
      'symptoms': [
        {'id': 'chills', 'label': 'Des frissons'},
        {'id': 'vomiting', 'label': 'Des vomissements'},
        {'id': 'stiff_neck', 'label': 'Une nuque raide'},
        {'id': 'confusion', 'label': 'Une confusion ou somnolence'},
      ],
      'submitLabel': 'Envoyer',
    },
  ];

  static List<Map<String, Object?>> _childAge() => [
    _info(
      'Occupons-nous de votre enfant',
      'Chez les tout-petits, la fièvre demande plus d\'attention.',
    ),
    {
      'id': 'age',
      'component': 'SelectInput',
      'label': 'Âge de l\'enfant',
      'placeholder': 'Choisir',
      'event': 'child_age',
      'options': [
        {'value': 'under_3_months', 'label': 'Moins de 3 mois'},
        {'value': '3_months_5_years', 'label': '3 mois à 5 ans'},
        {'value': '5_15_years', 'label': '5 à 15 ans'},
      ],
    },
  ];

  static List<Map<String, Object?>> _verdict(_Level level) => [
    _info(
      'Merci pour vos réponses',
      'Buvez de l\'eau et reposez-vous en attendant.',
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
      'Que voulez-vous faire ?',
      {'id': 'go_to_clinic', 'label': 'Aller à l\'accueil', 'icon': 'clinic'},
      [
        {
          'id': 'call_nurse',
          'label': 'Appeler un infirmier',
          'icon': 'phone',
          'call': 'clinic',
        },
      ],
    ),
  ];

  static List<Map<String, Object?>> _waitForHelp() => [
    _info(
      'Les secours sont prévenus',
      'Vous avez bien fait d\'appeler. Suivez ces gestes.',
      icon: 'heart',
      severity: 'high',
    ),
    {
      'id': 'steps',
      'component': 'ListCard',
      'title': 'En attendant les secours',
      'items': [
        {'title': 'Asseyez-vous', 'subtitle': 'Sans faire d\'effort.'},
        {'title': 'Ne restez pas seul', 'subtitle': 'Appelez un proche.'},
        {
          'title': 'Gardez votre téléphone',
          'subtitle': 'Ils peuvent rappeler.',
        },
      ],
    },
  ];

  static List<Map<String, Object?>> _goToDesk() => [
    _info(
      'Allez à l\'accueil',
      'Sans réseau, l\'infirmier terminera votre fiche avec vous.',
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
    'Soins à la maison',
    'Reposez-vous. Consultez sous 48 h si cela continue.',
    'Sous 48 h',
  ),
  moderate(
    'Consultation aujourd\'hui',
    'Venez à l\'accueil aujourd\'hui. Vous ferez un test du paludisme si vous avez de la fièvre.',
    '30 à 60 min',
  );

  const _Level(this.title, this.recommendation, this.waitTime);

  final String title;
  final String recommendation;
  final String waitTime;
}
