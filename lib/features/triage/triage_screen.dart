import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:genui/genui.dart';
import 'package:firebase_ai/firebase_ai.dart' as gemini;

import '../../catalog/strict_props.dart';
import '../../core/brand/lebenam_logo.dart';
import '../../core/config/gemini_config.dart';
import '../../core/theme/theme_controller.dart';
import 'demo/guard_demo_sheet.dart';
import 'offline/on_device_model.dart';
import 'offline/on_device_sheet.dart';
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

  /// Demo switch: simulates the clinic losing power or network.
  final _forceOffline = ValueNotifier<bool>(false);
  StreamSubscription<String>? _renderErrorsSub;
  late final StreamSubscription<String> _bypassSub;

  /// What the patient last said, shown above the agent's answer.
  String? _lastSaid;

  /// Replays the last patient turn (text or voice) after an error.
  VoidCallback? _retry;

  /// Scripted sentences for the live demo (fills the field, doesn't send).
  static const _demoScripts = [
    'I have had a fever and a headache for 3 days',
    'I have a strong pain in my chest and I find it hard to breathe',
    'My head hurts',
    'I cannot read well',
  ];

  @override
  void initState() {
    super.initState();
    _agent = _createAgent();
    _bypassSub = strictPropsBypassed.listen(_showBypass);
  }

  TriageAgent _createAgent() {
    final agent = TriageAgent(
      model: GeminiConfig.model,
      forceOffline: _forceOffline,
      onDevice: OnDeviceModel.instance,
    );
    _renderErrorsSub?.cancel();
    _renderErrorsSub = agent.renderErrors.listen(_showRenderError);
    return agent;
  }

  /// Makes visible what is normally silent: an interface refused before
  /// reaching the patient, and sent back to the agent to recompose.
  void _showRenderError(String message) =>
      _showDemoNotice('🛡 Interface refused, sent back to the agent', message);

  /// Guard off: the invented props reached the widget and nobody noticed.
  void _showBypass(String message) => _showDemoNotice(
    '⚠ Guard off: invented property accepted',
    '$message, shown without any error.',
    color: Colors.orange.shade900,
  );

  void _showDemoNotice(String title, String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          backgroundColor: color,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Gap(4),
              Text(message, maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
  }

  void _openGuardDemo() => showGuardDemoSheet(
    context,
    onInject: (scenario) => _agent.injectForDemo(scenario.a2ui),
  );

  @override
  void dispose() {
    _renderErrorsSub?.cancel();
    _bypassSub.cancel();
    _agent.dispose();
    _forceOffline.dispose();
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
      _lastSaid = 'Voice message · ${seconds < 1 ? 1 : seconds} s';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const LebenamWordmark(height: 20),
        actions: [
          const ThemeModeButton(),
          IconButton(
            tooltip: 'New consultation',
            onPressed: _newConsultation,
            icon: const Icon(Icons.edit_square),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) => switch (value) {
              '__guard' => _openGuardDemo(),
              '__offline' => _forceOffline.value = !_forceOffline.value,
              '__ondevice' => showOnDeviceSheet(context),
              _ => _fill(value),
            },
            itemBuilder: (_) => [
              for (final text in _demoScripts)
                PopupMenuItem(value: text, child: Text(text, maxLines: 2)),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: '__guard',
                child: Text('Demo: Dart guard'),
              ),
              // A plain item with a trailing check: CheckedPopupMenuItem
              // indents its text, out of line with the other items.
              PopupMenuItem(
                value: '__offline',
                child: Row(
                  children: [
                    const Expanded(child: Text('Simulate a network outage')),
                    const Gap(12),
                    Icon(
                      _forceOffline.value
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: '__ondevice',
                child: Text('On-device AI (Gemma)'),
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
                    _OfflineBanner(
                      forced: _forceOffline,
                      answered: _agent.answeredBy,
                      model: OnDeviceModel.instance,
                    ),
                    // ── The GenUI surface ──────────────────────────────────
                    Expanded(
                      child: _SurfaceArea(
                        agent: _agent,
                        lastSaid: _lastSaid,
                        suggestions: _demoScripts,
                        onSuggestion: _fill,
                        onRetry: _retry,
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
                        'Demo only. Not a substitute for medical advice.',
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
  });

  final TriageAgent agent;
  final String? lastSaid;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback? onRetry;

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
          child = LoadingSurface(
            key: const ValueKey('loading'),
            onDevice:
                agent.forceOffline.value &&
                OnDeviceModel.instance.status.value is Installed,
          );
        } else if (error != null) {
          child = _ErrorView(
            key: const ValueKey('error'),
            error: error,
            onRetry: onRetry,
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

/// Tells the room who composed the interface: shown while the cut is
/// simulated, and after any answer composed on the device.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.forced,
    required this.answered,
    required this.model,
  });

  final ValueListenable<bool> forced;
  final ValueListenable<AnswerSource> answered;
  final OnDeviceModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([forced, answered, model.status]),
      builder: (context, _) {
        final source = answered.value;
        final on = forced.value || source != AnswerSource.cloud;
        final gemma = switch (source) {
          AnswerSource.onDevice => true,
          AnswerSource.rules => false,
          AnswerSource.cloud => model.status.value is Installed,
        };
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: !on
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: ShapeDecoration(
                    color: theme.colorScheme.inverseSurface,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        gemma ? Icons.memory_rounded : Icons.power_off_rounded,
                        size: 18,
                        color: theme.colorScheme.onInverseSurface,
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          gemma
                              ? 'Offline · Gemma on this phone'
                              : 'Offline · on-device rules, no AI',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
  const _ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  String get _message => switch (error) {
    gemini.UnsupportedUserLocation() =>
      'The Gemini API is not available in this region.',
    gemini.ServiceApiNotEnabled() =>
      'Firebase AI Logic is not enabled on this Firebase project.',
    gemini.QuotaExceeded() =>
      'This project ran out of Gemini quota. Try again later.',
    gemini.FirebaseAIException(:final message) => message,
    TriageAgentException(:final message) => message,
    _ => 'Cannot connect. Check the network and try again.',
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
              'Something went wrong',
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
            if (onRetry != null)
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
