import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:genui/genui.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

import '../../core/config/api_key_store.dart';
import '../../core/theme/app_colors.dart';
import '../setup/api_key_screen.dart';
import 'triage_agent.dart';
import 'widgets/empty_surface.dart';
import 'widgets/loading_surface.dart';
import 'widgets/patient_input_bar.dart';

/// The only "screen" of the triage flow.
///
/// Top 30 %: the patient's input. Bottom 70 %: a GenUI [Surface], whose
/// content is decided at runtime by the agent. There is no navigation stack:
/// each agent answer replaces the interface.
class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _input = TextEditingController();
  late TriageAgent _agent;
  String? _lastText;

  /// Scripted sentences for the live demo (fills the field, doesn't send).
  static const _demoScripts = [
    (
      'Fièvre + maux de tête',
      "J'ai de la fièvre et des maux de tête depuis 3 jours",
    ),
    (
      'Douleur thoracique',
      "J'ai une forte douleur dans la poitrine et j'ai du mal à respirer",
    ),
    ('Maux de tête (vague)', "J'ai mal à la tête"),
  ];

  @override
  void initState() {
    super.initState();
    _agent = _createAgent();
  }

  TriageAgent _createAgent() =>
      TriageAgent(apiKey: ApiKeyStore.key!, model: ApiKeyStore.model);

  @override
  void dispose() {
    _agent.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send(String text) {
    _lastText = text;
    _input.clear();
    _agent.send(text);
  }

  void _newConsultation() {
    setState(() {
      _agent.dispose();
      _agent = _createAgent();
      _input.clear();
      _lastText = null;
    });
  }

  Future<void> _changeKey() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ApiKeyScreen(popOnSave: true)),
    );
    if (changed == true) _newConsultation();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.local_hospital_rounded, color: AppColors.accent),
            const Gap(10),
            const Text('Lébénam Triage'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle consultation',
            onPressed: _newConsultation,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Scénarios de démo',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == '__key') {
                _changeKey();
              } else {
                _input.text = value;
              }
            },
            itemBuilder: (_) => [
              for (final (label, text) in _demoScripts)
                PopupMenuItem(
                  value: text,
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text(label),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '__key',
                child: ListTile(
                  leading: Icon(Icons.key_rounded),
                  title: Text('Changer la clé API'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const Gap(8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListenableBuilder(
              listenable: _agent.isThinking,
              builder: (context, _) {
                final busy = _agent.isThinking.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── TOP 30 % — patient input ────────────────────────────
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Comment vous sentez-vous ?',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const Gap(14),
                            PatientInputBar(
                              controller: _input,
                              busy: busy,
                              onSubmit: _send,
                            ),
                            const Gap(10),
                            Text(
                              'Démonstration — ne remplace pas un avis médical.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── BOTTOM 70 % — the GenUI surface ─────────────────────
                    Expanded(
                      flex: 7,
                      child: _SurfaceArea(
                        agent: _agent,
                        onRetry: _lastText == null
                            ? null
                            : () => _agent.send(_lastText!),
                        onChangeKey: _changeKey,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Picks what to show below the input: loading, error, the agent's surface,
/// or the empty state, cross-fading with a slide-up between them.
class _SurfaceArea extends StatelessWidget {
  const _SurfaceArea({
    required this.agent,
    required this.onRetry,
    required this.onChangeKey,
  });

  final TriageAgent agent;
  final VoidCallback? onRetry;
  final VoidCallback onChangeKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          agent.isThinking,
          agent.currentSurfaceId,
          agent.error,
        ]),
        builder: (context, _) {
          final surfaceId = agent.currentSurfaceId.value;
          final error = agent.error.value;

          final Widget child;
          if (agent.isThinking.value) {
            child = const LoadingSurface(key: ValueKey('loading'));
          } else if (error != null) {
            child = _ErrorView(
              key: const ValueKey('error'),
              error: error,
              onRetry: onRetry,
              onChangeKey: onChangeKey,
            );
          } else if (surfaceId != null) {
            // ★ The whole interface below is composed by Gemini.
            child = SingleChildScrollView(
              key: ValueKey(surfaceId),
              padding: const EdgeInsets.all(16),
              child: Surface(surfaceContext: agent.contextFor(surfaceId)),
            );
          } else {
            child = const EmptySurface(key: ValueKey('empty'));
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onChangeKey,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback onChangeKey;

  bool get _isKeyError => error is gemini.InvalidApiKey;

  String get _message => switch (error) {
    gemini.InvalidApiKey() => 'La clé API Gemini est invalide.',
    gemini.UnsupportedUserLocation() =>
      "L'API Gemini n'est pas disponible depuis cette région.",
    gemini.GenerativeAIException(:final message) => message,
    TriageAgentException(:final message) => message,
    _ => 'Connexion impossible. Vérifiez le réseau et réessayez.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: AppColors.warning,
            ),
            const Gap(16),
            Text(
              'Oups, quelque chose a coincé',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(_message, textAlign: TextAlign.center),
            const Gap(20),
            if (_isKeyError)
              FilledButton.icon(
                onPressed: onChangeKey,
                icon: const Icon(Icons.key_rounded),
                label: const Text('Changer la clé API'),
              )
            else if (onRetry != null)
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
          ],
        ),
      ),
    );
  }
}
