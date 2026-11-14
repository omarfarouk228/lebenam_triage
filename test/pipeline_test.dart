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
    ['Help called', 'Help on the way', 'Sit down', 'Loosen'],
    ['Do this now', 'Drink often', 'Protect yourself from malaria'],
    ['Temperature', '39.2 °C', 'Fever for'],
    ['Your sheet', 'First name', 'Create my sheet'],
    ['Your medical history', 'Sickle cell disease', 'Confirm'],
    [
      'Afi',
      '34 years old · Moderate urgency',
      'Your symptoms',
      'Your consultation',
      'SMS reminder',
      'Save',
    ],
    ["Child's age"],
    ['Temperature (°C)'],
    ['Tap a picture', 'Where does it hurt?', 'Chest', 'My child'],
    ['I am here for your health'],
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
    expect(find.text('I am here to help you'), findsOneWidget);
    expect(find.text('Chills or sweating'), findsOneWidget);

    // Tapping two symptoms then "Send my answers" sends ONE event back to the agent.
    await tester.tap(find.text('Chills or sweating'));
    await tester.tap(find.text('Body aches'));
    await tester.pump();
    await tester.ensureVisible(find.text('Send my answers'));
    await tester.tap(find.text('Send my answers'));
    await tester.pump();

    expect(h.submitted, hasLength(1));
    final payload = _payloads(h);
    expect(payload, contains(TriageEvents.symptomsConfirmed));
    expect(payload, contains('Body aches'));
  });

  testWidgets('Ex. 2: moderate verdict + actions', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[1]);

    expect(_errors(h), isEmpty);
    expect(find.text('MODERATE URGENCY'), findsOneWidget);
    expect(find.text('Go to the clinic'), findsOneWidget);

    await tester.ensureVisible(find.text('Go to the clinic'));
    await tester.tap(find.text('Go to the clinic'));
    await tester.pump();
    expect(_payloads(h), contains('go_to_clinic'));
  });

  testWidgets('Ex. 3: vague headache: pre-filled TriageForm', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[2]);

    expect(_errors(h), isEmpty);
    expect(find.text('Tell me about your pain'), findsOneWidget);
    expect(find.text('Headache'), findsOneWidget);
  });

  testWidgets('Ex. 4: chest pain: red card + emergency call', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[3]);

    expect(_errors(h), isEmpty);
    expect(find.text('HIGH URGENCY'), findsOneWidget);

    // Call actions show the app-owned number, never one from the LLM.
    final call = find.textContaining(
      'Call emergency services  ·  118',
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

  testWidgets('CheckboxGroup sends the history once, on "Confirm"', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[8]);

    await tester.tap(find.text('Pregnant'));
    await tester.tap(find.text('Diabetes'));
    await tester.pump();
    expect(h.submitted, isEmpty, reason: 'checking a box stays local');

    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
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
    await tester.ensureVisible(find.text('Belly'));
    await tester.tap(find.text('Chest'));
    await tester.pump();
    await tester.tap(find.text('Belly'));
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
      'alarm text': (const TextTurn('My chest hurts'), 'HIGH URGENCY'),
      'fever text': (const TextTurn('I have a fever'), 'Chills'),
      'child text': (const TextTurn('My baby is sick'), "Child's age"),
      'vague text': (const TextTurn('I feel unwell'), 'Where does it hurt?'),
      'voice': (const VoiceTurn(), 'Chest'),
      'alarm picto': (
        const InteractionTurn('picto_selected', {'id': 'bleeding'}),
        'HIGH URGENCY',
      ),
      'belly picto': (
        const InteractionTurn('picto_selected', {'id': 'belly'}),
        'MODERATE URGENCY',
      ),
      'symptoms': (
        const InteractionTurn('symptoms_confirmed', {
          'confirmed': ['Chills'],
        }),
        'MODERATE URGENCY',
      ),
      'stiff neck': (
        const InteractionTurn('symptoms_confirmed', {
          'confirmed': ['A stiff neck'],
        }),
        'HIGH URGENCY',
      ),
      'low fever': (
        const InteractionTurn('vitals_submitted', {'temperatureC': 37.2}),
        'LOW URGENCY',
      ),
      'baby': (
        const InteractionTurn('child_age:under_3_months', {}),
        'HIGH URGENCY',
      ),
      'emergency called': (
        const InteractionTurn('action_selected', {
          'actionId': 'call_emergency',
        }),
        'While you wait for help',
      ),
      'anything else': (
        const InteractionTurn('form_submit', {}),
        'Go to the front desk',
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
          'summary': 'You have had a fever for three days.',
        },
        ['I understood', 'You have had a fever for three days.', 'Chills'],
      ),
      'alarm flag': (
        {'symptom': 'belly', 'alarm': true, 'summary': 'Your belly hurts.'},
        ['Your belly hurts.', 'HIGH URGENCY'],
      ),
      'alarm symptom without the flag': (
        {'symptom': 'chest_pain', 'alarm': false, 'summary': 'Chest pain.'},
        ['HIGH URGENCY'],
      ),
      'child': (
        {'symptom': 'child', 'alarm': false, 'summary': 'Your baby is hot.'},
        ["Child's age"],
      ),
      'other symptom': (
        {'symptom': 'cough', 'alarm': false, 'summary': 'You cough.'},
        ['MODERATE URGENCY'],
      ),
      'not understood': (
        {'symptom': 'other', 'alarm': false, 'summary': ''},
        ['Where does it hurt?'],
      ),
      'not about health': (
        {'symptom': 'not_health', 'alarm': false, 'summary': 'Weather.'},
        ['I am here for your health'],
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
