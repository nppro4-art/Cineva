import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';

/// Réglages du Cineva Audio Engine : activation, profils, curseurs,
/// dynamique, loudness, sortie et comparaison A/B.
class AudioSettingsScreen extends ConsumerWidget {
  const AudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioEngineControllerProvider);
    final settings = audio.settings;
    final controller = ref.read(audioEngineControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Cineva Audio')),
      body: CinevaScaffoldContainer(
        child: ListView(
          children: <Widget>[
            const CinevaPageHeader(
              title: 'Moteur audio Cineva',
              subtitle: 'Profils, dialogues, basses, dynamique et spatialisation — traitement temps réel.',
            ),
            const SizedBox(height: CinevaSpacing.xl),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activer le moteur audio'),
                    subtitle: Text(
                      audio.backendAvailable
                          ? 'Traitement ${audio.processingActive ? 'actif' : (settings.enabled ? 'en veille (aucun média branché)' : 'désactivé')}'
                          : 'Indisponible sur cet appareil — le son d\'origine est conservé.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: CinevaColors.textMuted),
                    ),
                    value: settings.enabled,
                    onChanged: controller.updateEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Profil sonore'),
                  const SizedBox(height: CinevaSpacing.md),
                  for (final CinevaAudioProfile profile in CinevaAudioProfile.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
                      child: _ProfileTile(
                        profile: profile,
                        selected: settings.profile == profile,
                        onTap: () => controller.updateProfile(profile),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Réglages fins'),
                  const SizedBox(height: CinevaSpacing.md),
                  _AmountSlider(
                    label: 'Clarté des dialogues',
                    value: settings.dialogueAmount,
                    icon: Icons.record_voice_over_outlined,
                    onChanged: controller.updateDialogueAmount,
                  ),
                  _AmountSlider(
                    label: 'Profondeur des basses',
                    value: settings.bassAmount,
                    icon: Icons.speaker_rounded,
                    onChanged: controller.updateBassAmount,
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Spatialisation'),
                    subtitle: Text(
                      settings.output == CinevaAudioOutput.headphone
                          ? 'Rendu binaural pour le casque'
                          : 'Élargissement de la scène sonore',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: CinevaColors.textMuted),
                    ),
                    value: settings.spatialEnabled,
                    onChanged: controller.updateSpatial,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Normalisation du volume'),
                    subtitle: Text(
                      'Aligne le niveau global (loudness) pour une écoute constante.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: CinevaColors.textMuted),
                    ),
                    value: settings.loudnessEnabled,
                    onChanged: controller.updateLoudness,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Dynamique'),
                  const SizedBox(height: CinevaSpacing.md),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: CinevaAudioDynamicRange.values
                        .map(
                          (range) => ChoiceChip(
                            label: Text(range.label),
                            selected: settings.dynamicRange == range,
                            onSelected: (_) => controller.updateDynamicRange(range),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),
                  const CinevaSectionTitle(title: 'Sortie audio'),
                  const SizedBox(height: CinevaSpacing.md),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: CinevaAudioOutput.values
                        .map(
                          (output) => ChoiceChip(
                            label: Text(output.label),
                            selected: settings.output == output,
                            onSelected: (_) => controller.updateOutput(output),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Comparaison A/B'),
                  const SizedBox(height: CinevaSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Écouter le son d\'origine (B)'),
                    subtitle: Text(
                      'Bypass instantané du moteur pendant la lecture pour comparer.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: CinevaColors.textMuted),
                    ),
                    value: settings.abCompare,
                    onChanged: (_) => controller.toggleAbCompare(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            Padding(
              padding: const EdgeInsets.only(bottom: CinevaSpacing.xl),
              child: OutlinedButton.icon(
                onPressed: () => context.push('/settings/audio/advanced'),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Réglages avancés (EQ, crossover, limiteur)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final CinevaAudioProfile profile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CinevaRadii.medium),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          border: Border.all(
            color: selected ? CinevaColors.accentSoft : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.md, vertical: CinevaSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? CinevaColors.accentSoft : CinevaColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: CinevaSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(profile.label, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    profile.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountSlider extends StatelessWidget {
  const _AmountSlider({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final double value;
  final IconData icon;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: CinevaSpacing.sm),
        Row(
          children: <Widget>[
            Icon(icon, size: 18, color: CinevaColors.textMuted),
            const SizedBox(width: CinevaSpacing.sm),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            Text('${value.round()}%',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: CinevaColors.accentSoft)),
          ],
        ),
        Slider(
          value: value,
          max: 100,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
