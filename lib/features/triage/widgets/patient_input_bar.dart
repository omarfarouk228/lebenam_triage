import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';
import '../voice/voice_recorder.dart';

/// Composer at the bottom of the triage screen: type the symptoms, or hold a
/// voice message.
///
/// This is the only hand-built input of the app: everything above it is
/// composed by the agent.
class PatientInputBar extends StatefulWidget {
  const PatientInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onVoice,
    required this.busy,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  /// Called with a WAV clip when the patient sends a voice message.
  final ValueChanged<Uint8List> onVoice;
  final bool busy;

  @override
  State<PatientInputBar> createState() => _PatientInputBarState();
}

class _PatientInputBarState extends State<PatientInputBar> {
  final _focus = FocusNode();
  final _voice = VoiceRecorder();
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _voice.onMaxDuration = _sendVoice;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  void _send() {
    if (widget.busy || !_hasText) return;
    _focus.unfocus();
    widget.onSubmit(widget.controller.text.trim());
  }

  Future<void> _startVoice() async {
    if (widget.busy) return;
    _focus.unfocus();
    if (!await _voice.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Autorisez le micro pour décrire vos symptômes.'),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    await _voice.start();
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _sendVoice() async {
    if (!_recording) return;
    setState(() => _recording = false);
    HapticFeedback.lightImpact();
    final wav = await _voice.stop();
    if (wav != null) widget.onVoice(wav);
  }

  Future<void> _cancelVoice() async {
    setState(() => _recording = false);
    await _voice.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _recording
          ? _RecordingBar(
              key: const ValueKey('recording'),
              recorder: _voice,
              onCancel: _cancelVoice,
              onSend: _sendVoice,
            )
          : _TextBar(
              key: const ValueKey('text'),
              controller: widget.controller,
              focus: _focus,
              busy: widget.busy,
              hasText: _hasText,
              onSend: _send,
              onMic: _startVoice,
            ),
    );
  }
}

class _TextBar extends StatelessWidget {
  const _TextBar({
    super.key,
    required this.controller,
    required this.focus,
    required this.busy,
    required this.hasText,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final bool hasText;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: TextField(
                controller: controller,
                focusNode: focus,
                enabled: !busy,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Décrivez vos symptômes',
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const Gap(6),
          // Empty field → mic; typed text → send. One slot, like the big
          // messaging apps.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: busy
                ? const _RoundButton(
                    key: ValueKey('busy'),
                    tooltip: 'Analyse en cours',
                    filled: false,
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : hasText
                ? _RoundButton(
                    key: const ValueKey('send'),
                    tooltip: 'Envoyer',
                    onTap: onSend,
                    child: const Icon(Icons.arrow_upward_rounded, size: 22),
                  )
                : _RoundButton(
                    key: const ValueKey('mic'),
                    tooltip: 'Parler',
                    onTap: onMic,
                    child: const Icon(Icons.mic_none_rounded, size: 22),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    super.key,
    required this.recorder,
    required this.onCancel,
    required this.onSend,
  });

  final VoiceRecorder recorder;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  static String _format(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      label: 'Enregistrement en cours',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            _RoundButton(
              tooltip: 'Annuler',
              filled: false,
              onTap: onCancel,
              child: const Icon(Icons.close_rounded, size: 22),
            ),
            const Gap(8),
            Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.urgent,
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1, end: 0.2, duration: 700.ms),
            const Gap(10),
            ValueListenableBuilder(
              valueListenable: recorder.elapsed,
              builder: (context, elapsed, _) => Text(
                _format(elapsed),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const Gap(14),
            Expanded(child: _LevelBars(level: recorder.level)),
            const Gap(8),
            _RoundButton(
              tooltip: 'Envoyer le message vocal',
              onTap: onSend,
              child: const Icon(Icons.arrow_upward_rounded, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of bars that breathe with the microphone level.
class _LevelBars extends StatefulWidget {
  const _LevelBars({required this.level});

  final ValueNotifier<double> level;

  @override
  State<_LevelBars> createState() => _LevelBarsState();
}

class _LevelBarsState extends State<_LevelBars> {
  static const _count = 24;
  final _history = List<double>.filled(_count, 0, growable: true);

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_onLevel);
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() => setState(() {
    _history
      ..removeAt(0)
      ..add(widget.level.value);
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final v in _history)
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 3,
              height: 4 + 24 * v,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.25 + 0.6 * v),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// 44 px circular button: ink-filled for the main action, plain otherwise.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.child,
    this.onTap,
    this.filled = true,
  });

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? scheme.primary : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 44,
            child: IconTheme(
              data: IconThemeData(
                color: filled ? scheme.onPrimary : scheme.onSurface,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
