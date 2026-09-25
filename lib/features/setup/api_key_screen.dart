import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/config/api_key_store.dart';
import '../../core/theme/app_colors.dart';
import '../triage/triage_screen.dart';

/// Fallback when no `--dart-define=GEMINI_API_KEY` was given: lets the
/// speaker paste a key on stage. The key is saved on the device.
class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key, this.popOnSave = false});

  /// `true` when opened from the triage screen (pop back instead of pushing).
  final bool popOnSave;

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 20;

  Future<void> _save() async {
    if (!_valid) return;
    await ApiKeyStore.save(_controller.text);
    if (!mounted) return;
    if (widget.popOnSave) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TriageScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(
                  Icons.key_rounded,
                  size: 48,
                  color: AppColors.accent,
                ),
                const Gap(16),
                Text('Clé API Gemini', style: theme.textTheme.headlineSmall),
                const Gap(8),
                Text(
                  "L'agent a besoin d'une clé Gemini pour composer l'interface. "
                  'Créez-en une gratuitement sur aistudio.google.com/apikey.',
                  style: theme.textTheme.bodyMedium,
                ),
                const Gap(24),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: 'Clé API',
                    hintText: 'AIza...',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const Gap(16),
                FilledButton(
                  onPressed: _valid ? _save : null,
                  child: const Text('Enregistrer et continuer'),
                ),
                const Gap(24),
                Text(
                  'Astuce : lancez l\'app avec\n'
                  'flutter run --dart-define=GEMINI_API_KEY=votre_clé\n'
                  'pour ne jamais afficher cet écran.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
