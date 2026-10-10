// ─────────────────────────────────────────────────────────────────────────────
// THE DART GUARD: rejects props the agent invented.
//
// genui validates what the LLM sends against each CatalogItem's dataSchema:
// bounds (`minimum`/`maximum`), enums and `required` are enforced, and a
// failure goes back to the agent, which recomposes.
//
// But unknown props are NOT rejected: `CatalogItem.dataSchema` (genui 0.10.3)
// rewrites every schema with `additionalProperties: true`, so writing
// `additionalProperties: false` has no effect. An invented prop reaches the
// widget builder silently.
//
// This wrapper closes the gap in plain Dart: before building, it compares the
// keys the agent sent with the keys the schema declares. Anything else is
// reported back to the agent through `ctx.reportError` (same path as genui's
// own validation errors) and the component is not rendered.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genui/genui.dart';

/// Turns the guard on and off at runtime (live demo only; on by default).
final strictPropsEnabled = ValueNotifier<bool>(true);

/// Live demo only: with the guard off, reports each component rendered
/// despite invented props (normally silent), as "Type: [props]".
Stream<String> get strictPropsBypassed => _bypassed.stream;
final _bypassed = StreamController<String>.broadcast();
final _reportedBypasses = <String>{};

/// Same [item], but a component carrying props absent from its schema is
/// rejected instead of rendered.
CatalogItem strictProps(CatalogItem item) {
  // Includes `component`, which genui adds to every schema.
  final allowed = {
    for (final key in (item.dataSchema.value['properties'] as Map).keys) '$key',
  };
  return CatalogItem(
    name: item.name,
    dataSchema: item.dataSchema,
    isImplicitlyFlexible: item.isImplicitlyFlexible,
    widgetBuilder: (ctx) {
      final unknown = [
        for (final key in (ctx.data as Map).keys)
          if (!allowed.contains('$key')) '$key',
      ];
      if (unknown.isEmpty) return item.widgetBuilder(ctx);
      if (!strictPropsEnabled.value) {
        // Builders run on every rebuild: report each component once.
        if (_reportedBypasses.add('${ctx.surfaceId}/${ctx.id}')) {
          debugPrint('⚠ Dart guard off: ${ctx.type} rendered with $unknown');
          _bypassed.add('${ctx.type}: $unknown');
        }
        return item.widgetBuilder(ctx);
      }
      return _Rejected(ctx: ctx, unknown: unknown, allowed: allowed);
    },
  );
}

/// Reports the rejection once per mounted component, after the frame: the
/// report starts a new agent turn, which must not happen during a build.
class _Rejected extends StatefulWidget {
  const _Rejected({
    required this.ctx,
    required this.unknown,
    required this.allowed,
  });

  final CatalogItemContext ctx;
  final List<String> unknown;
  final Set<String> allowed;

  @override
  State<_Rejected> createState() => _RejectedState();
}

class _RejectedState extends State<_Rejected> {
  @override
  void initState() {
    super.initState();
    final ctx = widget.ctx;
    final allowed = widget.allowed.where((k) => k != 'component').join(', ');
    debugPrint(
      '🛡 Dart guard: ${ctx.type} rejected, unknown ${widget.unknown}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctx.reportError(
        A2uiValidationException(
          'Unknown properties ${widget.unknown} for component ${ctx.id} '
          '(${ctx.type}). Allowed properties: $allowed. Recompose the '
          'interface using only these properties.',
          surfaceId: ctx.surfaceId,
          path: '/components/${ctx.id}',
        ),
        null,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
