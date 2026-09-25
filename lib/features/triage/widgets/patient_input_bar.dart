import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';

/// Free-text symptom input, quick chips and an animated send button.
///
/// This is the only hand-built input of the app: everything below it is
/// composed by the agent.
class PatientInputBar extends StatefulWidget {
  const PatientInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.busy,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool busy;

  @override
  State<PatientInputBar> createState() => _PatientInputBarState();
}

class _PatientInputBarState extends State<PatientInputBar> {
  final _focus = FocusNode();

  static const _chips = <(String, IconData, String?)>[
    ('Fièvre', Icons.thermostat_rounded, "J'ai de la fièvre"),
    ('Douleur', Icons.healing_rounded, "J'ai des douleurs"),
    ('Toux', Icons.air_rounded, 'Je tousse'),
    ('Autre', Icons.edit_note_rounded, null),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canSend => !widget.busy && widget.controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    _focus.unfocus();
    widget.onSubmit(widget.controller.text.trim());
  }

  /// Chips append a phrase to the current text ("Autre" only focuses).
  void _appendChip(String? phrase) {
    if (phrase != null) {
      final current = widget.controller.text.trim();
      final next = current.isEmpty
          ? phrase
          : '$current, ${phrase[0].toLowerCase()}${phrase.substring(1)}';
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                enabled: !widget.busy,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyLarge,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Décrivez vos symptômes...',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const Gap(10),
            _SendButton(enabled: _canSend, busy: widget.busy, onTap: _send),
          ],
        ),
        const Gap(12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (label, icon, phrase) in _chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(label),
                    onPressed: widget.busy ? null : () => _appendChip(phrase),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: enabled ? scheme.primary : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: busy
                  ? SizedBox.square(
                      key: const ValueKey('busy'),
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      key: const ValueKey('send'),
                      color: enabled ? scheme.onPrimary : scheme.outline,
                    ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Envoyer',
      // A gentle "ready" bounce each time the button becomes enabled.
      child: enabled
          ? button
                .animate(key: const ValueKey('ready'))
                .scaleXY(
                  begin: 0.85,
                  end: 1,
                  duration: 300.ms,
                  curve: Curves.easeOutBack,
                )
          : button,
    );
  }
}
