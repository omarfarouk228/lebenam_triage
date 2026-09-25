import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:genui/genui.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

import '../../core/brand/lebenam_logo.dart';
import '../../core/config/api_key_store.dart';
import '../../core/theme/theme_controller.dart';
import '../setup/api_key_screen.dart';
import 'triage_agent.dart';
import 'widgets/empty_surface.dart';
import 'widgets/loading_surface.dart';
import 'widgets/patient_input_bar.dart';

/// The only "screen" of the triage flow.
///
/// The GenUI [Surface] fills the screen, its content decided at runtime by
/// the agent; the patient's composer sits at the bottom, within thumb
/// reach. There is no navigation stack: each agent answer replaces the
/// interface.
class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  final _input = TextEditingController();
  late TriageAgent _agent;

  /// What the patient last said, shown above the agent's answer.
  String? _lastSaid;

  /// Replays the last patient turn (text or voice) after an error.
  VoidCallback? _retry;

  /// Scripted sentences for the live demo (fills the field, doesn't send).
  static const _demoScripts = [
    "J'ai de la fièvre et des maux de tête depuis 3 jours",
    "J'ai une forte douleur dans la poitrine et j'ai du mal à respirer",
    "J'ai mal à la tête",
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
    setState(() {
      _lastSaid = text;
      _retry = () => _agent.send(text);
    });
    _input.clear();
    _agent.send(text);
  }

  void _sendVoice(Uint8List wav) {
    // 16 kHz, 16-bit mono: 32 000 bytes per second after the 44-byte header.
    final seconds = ((wav.length - 44) / 32000).round();
    setState(() {
      _lastSaid = 'Message vocal · ${seconds < 1 ? 1 : seconds} s';
      _retry = () => _agent.sendVoice(wav);
    });
    _agent.sendVoice(wav);
  }

  void _fill(String text) {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _newConsultation() {
    setState(() {
      _agent.dispose();
      _agent = _createAgent();
      _input.clear();
      _lastSaid = null;
      _retry = null;
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
        title: const LebenamWordmark(height: 20),
        actions: [
          const ThemeModeButton(),
          IconButton(
            tooltip: 'Nouvelle consultation',
            onPressed: _newConsultation,
            icon: const Icon(Icons.edit_square),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) =>
                value == '__key' ? _changeKey() : _fill(value),
            itemBuilder: (_) => [
              for (final text in _demoScripts)
                PopupMenuItem(value: text, child: Text(text, maxLines: 2)),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '__key',
                child: Text('Changer la clé API'),
              ),
            ],
          ),
          const Gap(4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: _agent.isThinking,
              builder: (context, _) {
                final busy = _agent.isThinking.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── The GenUI surface ──────────────────────────────────
                    Expanded(
                      child: _SurfaceArea(
                        agent: _agent,
                        lastSaid: _lastSaid,
                        suggestions: _demoScripts,
                        onSuggestion: _fill,
                        onRetry: _retry,
                        onChangeKey: _changeKey,
                      ),
                    ),
                    // ── The patient's composer ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: PatientInputBar(
                        controller: _input,
                        busy: busy,
                        onSubmit: _send,
                        onVoice: _sendVoice,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Démonstration. Ne remplace pas un avis médical.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall,
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

/// Picks what to show above the composer: loading, error, the agent's
/// surface, or the empty state, cross-fading between them.
class _SurfaceArea extends StatelessWidget {
  const _SurfaceArea({
    required this.agent,
    required this.lastSaid,
    required this.suggestions,
    required this.onSuggestion,
    required this.onRetry,
    required this.onChangeKey,
  });

  final TriageAgent agent;
  final String? lastSaid;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback? onRetry;
  final VoidCallback onChangeKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
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
          child = SingleChildScrollView(
            key: ValueKey(surfaceId),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lastSaid != null) ...[
                  _PatientBubble(text: lastSaid!),
                  const Gap(16),
                ],
                // ★ The whole interface below is composed by Gemini.
                Surface(surfaceContext: agent.contextFor(surfaceId)),
              ],
            ),
          );
        } else {
          child = EmptySurface(
            key: const ValueKey('empty'),
            suggestions: suggestions,
            onSuggestion: onSuggestion,
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // Content hangs from the top (loading, answers); the empty and
          // error states fill the space and place themselves.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// The patient's last message, right-aligned like a sent chat message.
class _PatientBubble extends StatelessWidget {
  const _PatientBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
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
    gemini.GenerativeAIException(:final message)
        when message.contains('credits') ||
            message.contains('quota') ||
            message.contains('RESOURCE_EXHAUSTED') =>
      'Les crédits ou le quota Gemini de ce projet sont épuisés. '
          'Rechargez-les dans AI Studio, puis réessayez.',
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(20),
            Text(
              'Une erreur est survenue',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            if (_isKeyError)
              FilledButton(
                onPressed: onChangeKey,
                child: const Text('Changer la clé API'),
              )
            else if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
