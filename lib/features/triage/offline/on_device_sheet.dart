import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'on_device_model.dart';

/// Download and status of the on-device model (Gemma 4 E2B).
Future<void> showOnDeviceSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _OnDeviceSheet(),
);

class _OnDeviceSheet extends StatelessWidget {
  const _OnDeviceSheet();

  @override
  Widget build(BuildContext context) {
    final model = OnDeviceModel.instance;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final minHeight = MediaQuery.sizeOf(context).height * 0.5;
    return ListenableBuilder(
      listenable: Listenable.merge([model.status, model.lastLatency]),
      builder: (context, _) {
        final status = model.status.value;
        final latency = model.lastLatency.value;
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        size: 28,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IA sur l\'appareil',
                            style: textTheme.headlineSmall,
                          ),
                          Text(
                            'Gemma 4 E2B · GPU · 2,6 Go',
                            style: textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(24),
                Text(
                  'Quand le réseau disparaît, Gemma tourne sur ce téléphone. '
                  'Il comprend seulement le patient, par écrit ou à la '
                  'voix. L\'app compose toujours l\'interface, avec le même '
                  'catalogue et les mêmes contrôles Dart.',
                  style: textTheme.bodyLarge,
                ),
                const Gap(16),
                _Step(
                  icon: Icons.cloud_rounded,
                  text: 'En ligne : Gemini comprend et compose.',
                ),
                _Step(
                  icon: Icons.memory_rounded,
                  text: 'Hors-ligne : Gemma comprend, Dart compose.',
                ),
                _Step(
                  icon: Icons.rule_rounded,
                  text: 'Sans modèle : règles et pictogrammes.',
                ),
                const Gap(28),
                switch (status) {
                  NotInstalled() => SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: model.download,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        'Télécharger le modèle (2,6 Go, Wi-Fi)',
                      ),
                    ),
                  ),
                  Downloading(:final percent) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 12,
                        ),
                      ),
                      const Gap(12),
                      Text(
                        'Téléchargement… $percent %',
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Installed(loaded: false) => Row(
                    children: [
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const Gap(16),
                      Text(
                        'Chargement du modèle sur le GPU…',
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Installed(loaded: true) => Text(
                    latency == null
                        ? '✅ Prêt, hors-ligne'
                        : '✅ Prêt, hors-ligne · dernière réponse en '
                              '${(latency.inMilliseconds / 1000).toStringAsFixed(1)} s',
                    style: textTheme.titleMedium,
                  ),
                  Unavailable(:final reason) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Indisponible. Les règles répondent hors-ligne.',
                        style: textTheme.titleMedium,
                      ),
                      const Gap(4),
                      Text(reason, maxLines: 4, style: textTheme.bodySmall),
                      const Gap(16),
                      OutlinedButton(
                        onPressed: model.download,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                },
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const Gap(12),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
