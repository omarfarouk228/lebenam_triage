// Runs the few-shot examples of the system prompt through the real genui
// pipeline (transport → parser → SurfaceController → Surface), without any
// LLM. If an example stops matching a CatalogItem schema, this test fails:
// the prompt and the catalog can never silently drift apart.


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lebenam_triage/catalog/catalog_items.dart';
import 'package:lebenam_triage/core/constants/prompts.dart';

/// Splits the prompt into its examples (each = the ```json blocks under a
/// "## Exemple" heading).
List<String> _examples() {
  final parts = triageSystemPrompt.split('## Exemple').skip(1);
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

  test('the prompt contains the 4 documented examples', () {
    expect(examples, hasLength(4));
  });

  testWidgets('Ex. 1 — fever: InfoCard + SymptomChecker', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[0]);

    expect(_errors(h), isEmpty);
    expect(find.text('Je suis là pour vous aider'), findsOneWidget);
    expect(find.text('Des frissons ou sueurs'), findsOneWidget);

    // Tapping two symptoms then "Valider" sends ONE event back to the agent.
    await tester.tap(find.text('Des frissons ou sueurs'));
    await tester.tap(find.text('Des courbatures'));
    await tester.pump();
    await tester.ensureVisible(find.text('Valider mes réponses'));
    await tester.tap(find.text('Valider mes réponses'));
    await tester.pump();

    expect(h.submitted, hasLength(1));
    final payload = _payloads(h);
    expect(payload, contains(TriageEvents.symptomsConfirmed));
    expect(payload, contains('Des courbatures'));
  });

  testWidgets('Ex. 2 — moderate verdict + actions', (tester) async {
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

  testWidgets('Ex. 3 — vague headache: pre-filled TriageForm', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[2]);

    expect(_errors(h), isEmpty);
    expect(find.text('Parlez-moi de votre douleur'), findsOneWidget);
    expect(find.text('Mal de tête'), findsOneWidget);
  });

  testWidgets('Ex. 4 — chest pain: red card + emergency call', (tester) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await _render(tester, h, examples[3]);

    expect(_errors(h), isEmpty);
    expect(find.text('URGENCE ÉLEVÉE'), findsOneWidget);
    expect(find.text('Appeler les urgences'), findsOneWidget);
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
}
