// ─────────────────────────────────────────────────────────────────────────────
// THE CATALOG: the contract between Gemini and Flutter.
//
// A CatalogItem has three parts:
//   1. name        → the word the LLM writes in `"component": "UrgencyCard"`
//   2. dataSchema  → JSON Schema of the props the LLM is allowed to send.
//                    genui validates every generated component against it:
//                    a strict schema is the best guardrail against
//                    hallucinated props.
//   3. widgetBuilder → turns validated JSON into a real Flutter widget and
//                    wires user interactions back to the agent through
//                    `dispatchEvent`.
//
// The agent never sees a Widget and never writes Dart. It only chooses among
// the items below and fills in their data.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:genui/genui.dart';
import 'package:genui_catalog/genui_catalog.dart' as kit;
import 'package:json_schema_builder/json_schema_builder.dart';

import '../core/phone/dialer.dart';
import 'widgets/action_buttons_widget.dart';
import 'widgets/info_card_widget.dart';
import 'widgets/shared/severity.dart';
import 'widgets/shared/triage_card.dart';
import 'widgets/symptom_checker_widget.dart';
import 'widgets/triage_form_widget.dart';
import 'widgets/urgency_card_widget.dart';
import 'widgets/vital_input_widget.dart';

/// Catalog id the agent must reference in `createSurface`.
const triageCatalogId = 'lebenam_triage';

/// Names of the events our widgets send back to the agent.
///
/// Each event becomes a new user turn in the conversation: the agent reads
/// `name` + `context` and answers with a brand new interface.
abstract final class TriageEvents {
  static const symptomsConfirmed = 'symptoms_confirmed';
  static const triageSubmitted = 'triage_submitted';
  static const vitalsSubmitted = 'vitals_submitted';
  static const actionSelected = 'action_selected';
}

/// The full catalog handed to the `SurfaceController`.
///
/// It mixes our 6 healthcare items with 18 ready-made items from
/// [genui_catalog](https://pub.dev/packages/genui_catalog): the agent
/// composes both in the same interface. Only SearchBar is left out (one
/// event, so one LLM round trip, per keystroke). CheckboxGroup and
/// SwitchGroup are used with `submitLabel`: one event per answer, not per
/// toggle.
final triageCatalog = Catalog([
  // Healthcare items, built for this app.
  infoCardItem,
  urgencyCardItem,
  symptomCheckerItem,
  triageFormItem,
  actionButtonsItem,
  vitalInputItem,
  // genui_catalog: layout.
  kit.columnItem,
  kit.rowItem,
  // genui_catalog: data display.
  _animated(kit.kpiCardItem),
  _animated(kit.statRowItem),
  _animated(kit.chartCardItem),
  _animated(kit.dataTableItem),
  _animated(kit.listCardItem),
  _animated(kit.emptyStateItem),
  // genui_catalog: workflow.
  _animated(kit.stepperCardItem),
  _animated(kit.timelineCardItem),
  _animated(kit.statusBadgeItem, stretch: false),
  // genui_catalog: forms.
  _animated(kit.actionFormItem),
  _animated(kit.selectInputItem, card: true),
  _animated(kit.checkboxGroupItem, card: true),
  _animated(kit.switchGroupItem, card: true),
  _animated(kit.ratingInputItem),
  // genui_catalog: media.
  _animated(kit.profileCardItem),
  _animated(kit.mediaCardItem),
], catalogId: triageCatalogId);

/// Events handled inside the widget, never sent to the agent: stepping
/// through a StepperCard must not recompose the whole screen.
const localOnlyEvents = {
  kit.CatalogEvents.stepNext,
  kit.CatalogEvents.stepPrev,
};

/// Same genui_catalog item, with our staggered entrance animation. Cards
/// are stretched to the full width, like ours (some hug their content);
/// bare inputs ([card]) get a card around them.
CatalogItem _animated(
  CatalogItem item, {
  bool stretch = true,
  bool card = false,
}) => CatalogItem(
  name: item.name,
  dataSchema: item.dataSchema,
  widgetBuilder: (ctx) {
    Widget child = item.widgetBuilder(ctx);
    if (card) child = TriageCard(child: child);
    if (stretch) child = SizedBox(width: double.infinity, child: child);
    return _entrance(ctx, child);
  },
);

// ─── 1. InfoCard ─────────────────────────────────────────────────────────────

final infoCardItem = CatalogItem(
  name: 'InfoCard',
  dataSchema: S.object(
    description: 'Empathy message, advice or information. Always first.',
    properties: {
      'title': S.string(description: 'Short title (max 6 words).'),
      'body': S.string(description: '1–3 simple sentences, in French.'),
      'icon': _iconSchema,
      'severity': _severitySchema,
    },
    required: ['title', 'body'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    return _entrance(
      ctx,
      InfoCardWidget(
        title: data['title'] as String? ?? '',
        body: data['body'] as String? ?? '',
        icon: data['icon'] == null ? null : medicalIcon(data['icon'] as String),
        severity: Severity.parse(data['severity']),
      ),
    );
  },
);

// ─── 2. UrgencyCard ──────────────────────────────────────────────────────────

final urgencyCardItem = CatalogItem(
  name: 'UrgencyCard',
  dataSchema: S.object(
    description: 'Triage verdict. Colour is derived from `level`.',
    properties: {
      'level': S.string(
        description: 'low = green, moderate = orange, high = red.',
        enumValues: ['low', 'moderate', 'high'],
      ),
      'title': S.string(description: 'Verdict in a few words.'),
      'recommendation': S.string(description: 'What to do, one sentence.'),
      'waitTime': S.string(description: 'e.g. "Immédiat", "30 à 60 min".'),
      'reason': S.string(description: 'Why this level, one sentence.'),
    },
    required: ['level', 'title', 'recommendation'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    return _entrance(
      ctx,
      UrgencyCardWidget(
        severity: Severity.parse(data['level']),
        title: data['title'] as String? ?? '',
        recommendation: data['recommendation'] as String? ?? '',
        waitTime: data['waitTime'] as String?,
        reason: data['reason'] as String?,
      ),
    );
  },
);

// ─── 3. SymptomChecker ───────────────────────────────────────────────────────

final symptomCheckerItem = CatalogItem(
  name: 'SymptomChecker',
  dataSchema: S.object(
    description:
        'Yes/no checklist of 3 to 6 related symptoms to confirm. '
        'Sends `symptoms_confirmed` with {confirmed: [...], denied: [...]}.',
    properties: {
      'title': S.string(),
      'question': S.string(description: 'Optional instruction line.'),
      'symptoms': S.list(
        items: S.object(
          properties: {'id': S.string(), 'label': S.string()},
          required: ['id', 'label'],
        ),
        minItems: 1,
        maxItems: 8,
      ),
      'submitLabel': S.string(),
    },
    required: ['title', 'symptoms'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    final symptoms = [
      for (final s in _maps(data['symptoms']))
        (id: '${s['id'] ?? s['label']}', label: '${s['label'] ?? s['id']}'),
    ];
    return _entrance(
      ctx,
      SymptomCheckerWidget(
        title: data['title'] as String? ?? '',
        question: data['question'] as String?,
        symptoms: symptoms,
        submitLabel: data['submitLabel'] as String? ?? 'Valider mes réponses',
        // ↓ The interaction goes back to the agent as a UserActionEvent.
        onSubmit: (confirmed, denied) => ctx.dispatchEvent(
          UserActionEvent(
            name: TriageEvents.symptomsConfirmed,
            sourceComponentId: ctx.id,
            context: {'confirmed': confirmed, 'denied': denied},
          ),
        ),
      ),
    );
  },
);

// ─── 4. TriageForm ───────────────────────────────────────────────────────────

final triageFormItem = CatalogItem(
  name: 'TriageForm',
  dataSchema: S.object(
    description:
        'Structured form when information is missing. Pre-fill what the '
        'patient already said. Sends `triage_submitted` with '
        '{urgency, duration, bodyPart, symptoms}.',
    properties: {
      'title': S.string(),
      'urgency': S.integer(
        description: 'Pre-filled felt intensity, 1 (light) to 5 (unbearable).',
        minimum: 1,
        maximum: 5,
      ),
      'duration': S.string(description: 'Pre-selected duration option.'),
      'bodyPart': S.string(description: 'Pre-selected body part option.'),
      'symptoms': S.list(items: S.string()),
      'durationOptions': S.list(items: S.string()),
      'bodyParts': S.list(items: S.string()),
      'submitLabel': S.string(),
    },
    required: ['title'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    return _entrance(
      ctx,
      TriageFormWidget(
        title: data['title'] as String? ?? '',
        urgency: (data['urgency'] as num?)?.toInt() ?? 3,
        duration: data['duration'] as String?,
        bodyPart: data['bodyPart'] as String?,
        symptoms: _strings(data['symptoms']),
        durationOptions: _strings(
          data['durationOptions'],
        ).orIfEmpty(TriageFormWidget.defaultDurations),
        bodyParts: _strings(
          data['bodyParts'],
        ).orIfEmpty(TriageFormWidget.defaultBodyParts),
        submitLabel: data['submitLabel'] as String? ?? 'Envoyer',
        onSubmit: (r) => ctx.dispatchEvent(
          UserActionEvent(
            name: TriageEvents.triageSubmitted,
            sourceComponentId: ctx.id,
            context: {
              'urgency': r.urgency,
              'duration': ?r.duration,
              'bodyPart': ?r.bodyPart,
              'symptoms': r.symptoms,
            },
          ),
        ),
      ),
    );
  },
);

// ─── 5. ActionButtons ────────────────────────────────────────────────────────

final _actionSchema = S.object(
  properties: {
    'id': S.string(description: 'snake_case, e.g. "call_emergency".'),
    'label': S.string(),
    'icon': _iconSchema,
    'emergency': S.boolean(description: 'true → rendered in red.'),
    'call': S.string(
      description:
          'Set when tapping must open the phone dialer: "emergency" '
          '(emergency services) or "clinic" (nurse / clinic). The app '
          'owns the numbers.',
      enumValues: ['emergency', 'clinic'],
    ),
  },
  required: ['id', 'label'],
);

final actionButtonsItem = CatalogItem(
  name: 'ActionButtons',
  dataSchema: S.object(
    description:
        'Next steps. Ends every triage. Sends `action_selected` with '
        '{actionId, label}.',
    properties: {
      'title': S.string(),
      'primary': _actionSchema,
      'secondary': S.list(items: _actionSchema, maxItems: 3),
    },
    required: ['primary'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    return _entrance(
      ctx,
      ActionButtonsWidget(
        title: data['title'] as String?,
        primary: _action(data['primary'] as Map? ?? const {}),
        secondary: [for (final a in _maps(data['secondary'])) _action(a)],
        onAction: (action) => ctx.dispatchEvent(
          UserActionEvent(
            name: TriageEvents.actionSelected,
            sourceComponentId: ctx.id,
            context: {'actionId': action.id, 'label': action.label},
          ),
        ),
      ),
    );
  },
);

TriageAction _action(Map<dynamic, dynamic> a) {
  final id = '${a['id'] ?? 'action'}';
  final emergency = a['emergency'] == true;
  return (
    id: id,
    label: '${a['label'] ?? ''}',
    icon: a['icon'] as String?,
    emergency: emergency,
    // Lenient: a "call_*" action without `call` still dials.
    call:
        CallTarget.parse(a['call']) ??
        (id.startsWith('call')
            ? (emergency ? CallTarget.emergency : CallTarget.clinic)
            : null),
  );
}

// ─── 6. VitalInput ───────────────────────────────────────────────────────────

final vitalInputItem = CatalogItem(
  name: 'VitalInput',
  dataSchema: S.object(
    description:
        'Capture temperature (and optionally heart rate). Sends '
        '`vitals_submitted` with {temperatureC, heartRateBpm}.',
    properties: {
      'title': S.string(),
      'note': S.string(description: 'How to measure, one sentence.'),
      'askHeartRate': S.boolean(),
      'submitLabel': S.string(),
    },
    required: ['title'],
  ),
  widgetBuilder: (ctx) {
    final data = _json(ctx);
    return _entrance(
      ctx,
      VitalInputWidget(
        title: data['title'] as String? ?? '',
        note: data['note'] as String?,
        askHeartRate: data['askHeartRate'] == true,
        submitLabel: data['submitLabel'] as String? ?? 'Envoyer les mesures',
        onSubmit: (v) => ctx.dispatchEvent(
          UserActionEvent(
            name: TriageEvents.vitalsSubmitted,
            sourceComponentId: ctx.id,
            context: {
              'temperatureC': ?(v.temperatureC == 0 ? null : v.temperatureC),
              'heartRateBpm': ?v.heartRateBpm,
            },
          ),
        ),
      ),
    );
  },
);

// ─── Shared schema fragments & helpers ───────────────────────────────────────

final _severitySchema = S.string(
  description: 'Background tint.',
  enumValues: ['info', 'low', 'moderate', 'high'],
);

final _iconSchema = S.string(
  enumValues: [
    'heart',
    'medical',
    'thermometer',
    'clock',
    'warning',
    'info',
    'water',
    'rest',
    'phone',
    'emergency',
    'clinic',
    'doctor',
    'pill',
    'learn',
    'hand',
    'lungs',
    'brain',
  ],
);

Map<String, Object?> _json(CatalogItemContext ctx) =>
    (ctx.data as Map).cast<String, Object?>();

Iterable<Map<dynamic, dynamic>> _maps(Object? raw) =>
    raw is List ? raw.whereType<Map<dynamic, dynamic>>() : const [];

List<String> _strings(Object? raw) =>
    raw is List ? raw.map((e) => '$e').toList() : const [];

extension on List<String> {
  List<String> orIfEmpty(List<String> fallback) => isEmpty ? fallback : this;
}

/// Staggered slide-up entrance.
///
/// Each card looks up its own position among the root Column's children, so
/// cards appear one after another (120 ms apart) whatever the agent composed.
Widget _entrance(CatalogItemContext ctx, Widget child) {
  final children = ctx.getComponent('root')?.properties['children'];
  final index = children is List ? children.indexOf(ctx.id) : 0;
  return child
      .animate(delay: (120 * (index < 0 ? 0 : index)).ms)
      .fadeIn(duration: 400.ms, curve: Curves.easeOut)
      .slideY(
        begin: 0.06,
        end: 0,
        duration: 400.ms,
        curve: Curves.easeOutCubic,
      );
}
