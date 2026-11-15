// The Dart guard of the talk "Dart as a Security Layer", run through the
// real genui pipeline with the exact scenarios of the live demo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lebenam_triage/catalog/catalog_items.dart';
import 'package:lebenam_triage/catalog/strict_props.dart';
import 'package:lebenam_triage/features/triage/demo/guard_demo_sheet.dart';

final _inventedProp = GuardScenario.all[0];
final _outOfBounds = GuardScenario.all[1];

/// Renders [scenario] as if the agent had sent it; returns the errors
/// reported back to the agent.
Future<List<String>> _play(WidgetTester tester, GuardScenario scenario) async {
  final controller = SurfaceController(catalogs: [triageCatalog]);
  final transport = A2uiTransportAdapter(onSend: (_) async {});
  final conversation = Conversation(
    controller: controller,
    transport: transport,
  );
  addTearDown(() {
    conversation.dispose();
    transport.dispose();
    controller.dispose();
  });

  final errors = <String>[];
  controller.onSubmit.listen((m) {
    for (final p in m.parts) {
      if (p is DataPart) {
        final payload = UiInteractionPart.fromDataPart(p).interaction;
        if (payload.contains('"error"')) errors.add(payload);
      }
    }
  });

  transport.addChunk(scenario.a2ui.replaceAll('{{surfaceId}}', 'demo'));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Surface(surfaceContext: controller.contextFor('demo')),
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return errors;
}

void main() {
  setUp(() => strictPropsEnabled.value = true);

  test(
    'genui overrides additionalProperties: false (why the guard exists)',
    () {
      // If this fails, genui now honours the keyword: update the talk.
      expect(triageFormItem.dataSchema.value['additionalProperties'], isTrue);
    },
  );

  testWidgets('without the guard, an invented prop passes silently', (
    tester,
  ) async {
    strictPropsEnabled.value = false;
    final errors = await _play(tester, _inventedProp);

    expect(errors, isEmpty);
    expect(find.text('Parlez-moi de votre douleur'), findsOneWidget);
  });

  testWidgets('the guard rejects an invented prop and tells the agent once', (
    tester,
  ) async {
    final errors = await _play(tester, _inventedProp);

    expect(errors, hasLength(1));
    expect(errors.single, contains('VALIDATION_FAILED'));
    expect(errors.single, contains('painScore'));
    expect(find.text('Parlez-moi de votre douleur'), findsNothing);
    expect(find.text('Je vous écoute'), findsOneWidget);
  });

  testWidgets('genui itself rejects an out-of-bounds value', (tester) async {
    strictPropsEnabled.value = false;
    final errors = await _play(tester, _outOfBounds);

    expect(errors, hasLength(1));
    expect(errors.single, contains('exceeds maximum of 5'));
  });
}
