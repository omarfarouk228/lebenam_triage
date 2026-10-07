// Live demo of the talk "Dart as a Security Layer": plays prepared
// hallucinations through the real pipeline, without relying on Gemini to
// hallucinate on cue.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../catalog/strict_props.dart';

/// A prepared agent answer: an InfoCard plus a TriageForm whose props
/// contain [extra].
class GuardScenario {
  const GuardScenario({
    required this.title,
    required this.caughtBy,
    required this.extra,
  });

  final String title;

  /// Who is expected to refuse it, shown to the audience.
  final String caughtBy;

  /// The faulty props, as JSON (e.g. `"painScore": 9`).
  final String extra;

  static const _formStart =
      '{"id": "form", "component": "TriageForm", '
      '"title": "Parlez-moi de votre douleur", "urgency": 3, '
      '"bodyPart": "Tête", ';

  /// The TriageForm line, as the agent would write it.
  String get formLine => '$_formStart$extra}';

  /// Both A2UI messages, ready for `TriageAgent.injectForDemo`.
  String get a2ui =>
      '```json\n'
      '{"version": "v0.9", "createSurface": {"surfaceId": "{{surfaceId}}", '
      '"catalogId": "lebenam_triage", "sendDataModel": true}}\n'
      '```\n'
      '```json\n'
      '{"version": "v0.9", "updateComponents": {"surfaceId": "{{surfaceId}}", '
      '"components": [\n'
      '{"id": "root", "component": "Column", "spacing": 16, '
      '"children": ["empathy", "form"]},\n'
      '{"id": "empathy", "component": "InfoCard", "title": "Je vous écoute", '
      '"body": "Précisez votre douleur pour que je vous oriente.", '
      '"icon": "hand", "severity": "info"},\n'
      '$formLine]}}\n'
      '```';

  static const all = [
    GuardScenario(
      title: 'Propriété inventée',
      caughtBy: 'Garde Dart (strictProps)',
      extra: '"painScore": 9',
    ),
    GuardScenario(
      title: 'Valeur hors bornes',
      caughtBy: 'Schéma genui (maximum: 5)',
      extra: '"urgency": 9',
    ),
  ];
}

/// Bottom sheet: the guard switch and one "inject" button per scenario.
Future<void> showGuardDemoSheet(
  BuildContext context, {
  required ValueChanged<GuardScenario> onInject,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Démo : Dart comme couche de sécurité',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(8),
          ValueListenableBuilder(
            valueListenable: strictPropsEnabled,
            builder: (context, enabled, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Garde Dart (strictProps)'),
              subtitle: Text(
                enabled
                    ? 'Les propriétés inconnues sont rejetées'
                    : 'Désactivée : seul le schéma genui valide',
              ),
              value: enabled,
              onChanged: (v) => strictPropsEnabled.value = v,
            ),
          ),
          for (final s in GuardScenario.all) ...[
            const Gap(12),
            _ScenarioCard(
              scenario: s,
              onInject: () {
                Navigator.of(context).pop();
                onInject(s);
              },
            ),
          ],
        ],
      ),
    ),
  ),
);

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario, required this.onInject});

  final GuardScenario scenario;
  final VoidCallback onInject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(scenario.title, style: theme.textTheme.titleSmall),
            Text(
              'Attendu : ${scenario.caughtBy}',
              style: theme.textTheme.bodySmall,
            ),
            const Gap(8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFFEEFFFF),
                  ),
                  children: [
                    const TextSpan(text: GuardScenario._formStart),
                    TextSpan(
                      text: scenario.extra,
                      style: const TextStyle(
                        color: Color(0xFFF07178),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: '}'),
                  ],
                ),
              ),
            ),
            const Gap(12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onInject,
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text("Injecter comme réponse de l'agent"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
