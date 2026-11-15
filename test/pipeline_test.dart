// Runs the few-shot examples of the system prompt through the real genui
// pipeline (transport → parser → SurfaceController → Surface), without any
// LLM. If an example stops matching a CatalogItem schema, this test fails:
// the prompt and the catalog can never silently drift apart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lebenam_triage/catalog/catalog_items.dart';
import 'package:lebenam_triage/core/constants/prompts.dart';
import 'package:lebenam_triage/features/triage/offline/offline_triage.dart';

/// Splits the prompt into its examples (each = the ```json blocks under a
/// "## Example" heading).
List<String> _examples() {
  final parts = triageSystemPrompt.split('## Example').skip(1);
  return [
    for (final part in parts)
      RegExp(
        r'```json[\s\S]*?```',
      ).allMatches(part).map((m) => m[0]).join('\n'),
  ];
}

class _Harness {
  _Harness() {
    transport = A2uiTransportAdapter(onSend: (_) async {});
    conversation = Conversation(controller: controller, transport: transport);
    controller.onSubmit.listen(submitted.add);
    controller.surfaceUpdates.listen((u) {
      if (u case ComponentsUpdated(:final surfaceId)) lastSurface = surfaceId;
    });
  }

  final controller = SurfaceController(catalogs: [triageCatalog]);
  late final A2uiTransportAdapter transport;
  late final Conversation conversation;
  final submitted = <ChatMessage>[];
  String? lastSurface;

  void dispose() {
    conversation.dispose();
    transport.dispose();
    controller.dispose();
  }
}

Future<void> _render(WidgetTester tester, _Harness h, String json) async {
  // Feed the text in small chunks, like a streaming LLM would.
  for (var i = 0; i < json.length; i += 40) {
    h.transport.addChunk(
      json.substring(i, i + 40 > json.length ? json.length : i + 40),
    );
  }
  await tester.pump(const Duration(milliseconds: 50));
  expect(h.lastSurface, isNotNull, reason: 'no surface was rendered');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Surface(
            surfaceContext: h.controller.contextFor(h.lastSurface!),
          ),
        ),
      ),
    ),
  );
  // Let the staggered entrance animations run (some loop forever, so no
  // pumpAndSettle).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Everything sent back to the agent (UI events and render errors), decoded.
String _payloads(_Harness h) => [
  for (final m in h.submitted)
    for (final p in m.parts)
      if (p is DataPart) UiInteractionPart.fromDataPart(p).interaction,
].join('\n');

/// Only the render errors (validation failures) reported to the agent.
String _errors(_Harness h) =>
    _payloads(h).split('\n').where((l) => l.contains('"error"')).join('\n');

void main() {
  final examples = _examples();

  test('the prompt contains the 14 documented examples', () {
    expect(examples, hasLength(14));
  });

  // Every example must pass genui's schema validation and render, including
  // the genui_catalog components it uses.
  for (final (i, texts) in [
    ['Secours appelés', 'Secours en route', 'Asseyez-vous', 'Desserrez'],
    ['À faire dès maintenant', 'Buvez souvent', 'Se protéger du paludisme'],
    ['Température', '39,2 °C', 'Fièvre depuis'],
    ['Votre fiche', 'Prénom', 'Créer ma fiche'],
    ['Vos antécédents', 'Drépanocytose', 'Valider'],
    [
      'Afi',
      '34 ans · Urgence modérée',
      'Vos symptômes',
      'Votre consultation',
      'Rappel par SMS',
      'Enregistrer',
    ],
    ["Âge de l'enfant"],
    ['Température (°C)'],
    ['Touchez une image', 'Où avez-vous mal ?', 'Poitrine', 'Mon enfant'],
    ['Je suis là pour votre santé'],
  ].indexed) {
    final n = i + 5;
    testWidgets('Ex. $n renders with genui_catalog components', (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await _render(tester, h, examples[n - 1]);

      expect(_errors(h), isEmpty);
      for (final text in texts) {
        expect(
          find.textContaining(text, findRichText: true),
          findsWidgets,
          reason: 'Ex. $n: "$text" not rendered',
        );
      }
    });
  }

  testWidgets('Ex. 1: fever: InfoCard + SymptomChecker', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[0]);

    expect(_errors(h), isEmpty);
    expect(find.text('Je suis là pour vous aider'), findsOneWidget);
    expect(find.text('Des frissons ou des sueurs'), findsOneWidget);

    // Tapping two symptoms then "Envoyer mes réponses" sends ONE event back
    // to the agent.
    await tester.tap(find.text('Des frissons ou des sueurs'));
    await tester.tap(find.text('Des courbatures'));
    await tester.pump();
    await tester.ensureVisible(find.text('Envoyer mes réponses'));
    await tester.tap(find.text('Envoyer mes réponses'));
    await tester.pump();

    expect(h.submitted, hasLength(1));
    final payload = _payloads(h);
    expect(payload, contains(TriageEvents.symptomsConfirmed));
    expect(payload, contains('Des courbatures'));
  });

  testWidgets('Ex. 2: moderate verdict + actions', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[1]);

    expect(_errors(h), isEmpty);
    expect(find.text('URGENCE MODÉRÉE'), findsOneWidget);
    expect(find.text('Aller à la clinique'), findsOneWidget);

    await tester.ensureVisible(find.text('Aller à la clinique'));
    await tester.tap(find.text('Aller à la clinique'));
    await tester.pump();
    expect(_payloads(h), contains('go_to_clinic'));
  });

  testWidgets('Ex. 3: vague headache: pre-filled TriageForm', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[2]);

    expect(_errors(h), isEmpty);
    expect(find.text('Parlez-moi de votre douleur'), findsOneWidget);
    expect(find.text('Mal de tête'), findsOneWidget);
  });

  testWidgets('Ex. 4: chest pain: red card + emergency call', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[3]);

    expect(_errors(h), isEmpty);
    expect(find.text('URGENCE ÉLEVÉE'), findsOneWidget);

    // Call actions show the app-owned number, never one from the LLM.
    final call = find.textContaining(
      'Appeler les urgences  ·  118',
      findRichText: true,
    );
    expect(call, findsOneWidget);

    // Tapping opens the dialer (no plugin in tests: handled) and still
    // reports the action to the agent.
    await tester.ensureVisible(call);
    await tester.tap(call);
    await tester.pump();
    expect(_payloads(h), contains('call_emergency'));
  });

  testWidgets('an unknown component is reported back to the agent', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.transport.addChunk(
      '```json\n{"version": "v0.9", "createSurface": {"surfaceId": "x", '
      '"catalogId": "lebenam_triage", "sendDataModel": true}}\n```\n'
      '```json\n{"version": "v0.9", "updateComponents": {"surfaceId": "x", '
      '"components": [{"id": "root", "component": "Column", "children": '
      '["a"]}, {"id": "a", "component": "HeartRateChart"}]}}\n```',
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(_errors(h), contains('HeartRateChart'));
  });

  testWidgets('CheckboxGroup sends the history once, on "Valider"', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[8]);

    await tester.tap(find.text('Enceinte'));
    await tester.tap(find.text('Diabète'));
    await tester.pump();
    expect(h.submitted, isEmpty, reason: 'checking a box stays local');

    await tester.ensureVisible(find.text('Valider'));
    await tester.tap(find.text('Valider'));
    await tester.pump();
    expect(h.submitted, hasLength(1));
    expect(_payloads(h), contains('medical_history:pregnancy,diabetes'));
  });

  testWidgets('RatingInput sends the rating to the agent', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[9]);

    final stars = find.byIcon(Icons.star_border);
    await tester.ensureVisible(stars.first);
    await tester.tap(stars.at(3));
    await tester.pump();
    final payload = _payloads(h);
    expect(payload, contains('rating_submitted'));
    expect(payload, contains('"rating":4'));
  });

  testWidgets('PictoChoice: one tap sends picto_selected', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[12]);

    expect(_errors(h), isEmpty);
    await tester.ensureVisible(find.text('Ventre'));
    await tester.tap(find.text('Poitrine'));
    await tester.pump();
    await tester.tap(find.text('Ventre'));
    await tester.pump();

    expect(h.submitted, hasLength(1), reason: 'one tap answers, once');
    final payload = _payloads(h);
    expect(payload, contains(TriageEvents.pictoSelected));
    expect(payload, contains('chest_pain'));
  });

  // The offline rules speak the same protocol to the same catalog: every
  // answer must pass genui's validation and the Dart guard, like Gemini's.
  group('offline triage', () {
    final cases = <String, (OfflineTurn, String)>{
      'alarm text': (
        const TextTurn("J'ai mal à la poitrine"),
        'URGENCE ÉLEVÉE',
      ),
      // Typed without accents: the rules must still recognise the fever.
      'fever text': (
        const TextTurn("J'ai de la fievre depuis trois jours"),
        'Des frissons',
      ),
      // A baby with a fever: the age question comes before the fever one.
      'child text': (
        const TextTurn('Mon bébé a de la fièvre depuis hier'),
        "Âge de l'enfant",
      ),
      'vague text': (
        const TextTurn('Je ne me sens pas bien'),
        'Où avez-vous mal ?',
      ),
      'voice': (const VoiceTurn(), 'Poitrine'),
      'alarm picto': (
        const InteractionTurn('picto_selected', {'id': 'bleeding'}),
        'URGENCE ÉLEVÉE',
      ),
      'belly picto': (
        const InteractionTurn('picto_selected', {'id': 'belly'}),
        'URGENCE MODÉRÉE',
      ),
      'symptoms': (
        const InteractionTurn('symptoms_confirmed', {
          'confirmed': ['Des frissons'],
        }),
        'URGENCE MODÉRÉE',
      ),
      'stiff neck': (
        const InteractionTurn('symptoms_confirmed', {
          'confirmed': ['Une nuque raide'],
        }),
        'URGENCE ÉLEVÉE',
      ),
      'low fever': (
        const InteractionTurn('vitals_submitted', {'temperatureC': 37.2}),
        'URGENCE FAIBLE',
      ),
      'baby': (
        const InteractionTurn('child_age:under_3_months', {}),
        'URGENCE ÉLEVÉE',
      ),
      'emergency called': (
        const InteractionTurn('action_selected', {
          'actionId': 'call_emergency',
        }),
        'En attendant les secours',
      ),
      'anything else': (
        const InteractionTurn('form_submit', {}),
        "Allez à l'accueil",
      ),
    };
    for (final MapEntry(key: name, value: (turn, text)) in cases.entries) {
      testWidgets(name, (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);
        await _render(tester, h, OfflineTriage.respond(turn, 'offline-1'));

        expect(_errors(h), isEmpty);
        expect(find.textContaining(text, findRichText: true), findsWidgets);
      });
    }
  });

  // What Gemma writes on the phone is untrusted too: Dart checks the three
  // fields, then the rules compose an interface that must render.
  group('on-device understanding', () {
    test('rejects JSON outside the vocabulary', () {
      expect(Understanding.tryParse('fever'), isNull);
      expect(Understanding.tryParse({'symptom': 'malaria'}), isNull);
      expect(Understanding.tryParse({'alarm': true}), isNull);
      final long = Understanding.tryParse({
        'symptom': 'cough',
        'summary': 'x' * 500,
      });
      expect(long?.summary, isNull, reason: 'too long: not shown');
      expect(long?.alarm, isFalse);
    });

    final cases = <String, (Map<String, Object?>, List<String>)>{
      'fever, heard in French': (
        {
          'symptom': 'fever',
          'alarm': false,
          'summary': 'Vous avez de la fièvre depuis trois jours.',
        },
        [
          "J'ai compris",
          'Vous avez de la fièvre depuis trois jours.',
          'Des frissons',
        ],
      ),
      'alarm flag': (
        {
          'symptom': 'belly',
          'alarm': true,
          'summary': 'Vous avez mal au ventre.',
        },
        ['Vous avez mal au ventre.', 'URGENCE ÉLEVÉE'],
      ),
      'alarm symptom without the flag': (
        {
          'symptom': 'chest_pain',
          'alarm': false,
          'summary': 'Vous avez mal à la poitrine.',
        },
        ['URGENCE ÉLEVÉE'],
      ),
      'child': (
        {
          'symptom': 'child',
          'alarm': false,
          'summary': 'Votre bébé a de la fièvre.',
        },
        ["Âge de l'enfant"],
      ),
      'other symptom': (
        {'symptom': 'cough', 'alarm': false, 'summary': 'Vous toussez.'},
        ['URGENCE MODÉRÉE'],
      ),
      'not understood': (
        {'symptom': 'other', 'alarm': false, 'summary': ''},
        ['Où avez-vous mal ?'],
      ),
      'not about health': (
        {'symptom': 'not_health', 'alarm': false, 'summary': 'La météo.'},
        ['Je suis là pour votre santé'],
      ),
    };
    for (final MapEntry(key: name, value: (json, texts)) in cases.entries) {
      testWidgets(name, (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);
        final u = Understanding.tryParse(json)!;
        await _render(tester, h, OfflineTriage.respondUnderstood(u, 'gemma-1'));

        expect(_errors(h), isEmpty);
        for (final text in texts) {
          expect(
            find.textContaining(text, findRichText: true),
            findsWidgets,
            reason: '"$text" not rendered',
          );
        }
      });
    }
  });
}
