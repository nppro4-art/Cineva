import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

class VideoPreferencesScreen extends ConsumerWidget {
  const VideoPreferencesScreen({super.key});

  static const qualityValues = <String>['auto', '480p', '720p', '1080p', '1440p', '4k'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ?? AppSettingsModel.defaults();
    final vision = ref.watch(visionControllerProvider);
    final capabilities = vision.capabilities;

    return Scaffold(
      appBar: AppBar(title: const Text('Préférences vidéo')),
      body: CinevaScaffoldContainer(
        child: ListView(
          children: <Widget>[
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Qualité vidéo globale'),
                  const SizedBox(height: CinevaSpacing.md),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: qualityValues
                        .map(
                          (quality) => ChoiceChip(
                            label: Text(quality.toUpperCase()),
                            selected: settings.videoQuality == quality,
                            onSelected: (_) => ref.read(settingsControllerProvider.notifier).updateVideoQuality(quality),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),
                  Text(
                    'Mode recommandé : ${capabilities?.recommendedModeLabel ?? 'Analyse en cours'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CinevaSpacing.lg),
            CinevaGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const CinevaSectionTitle(title: 'Lecture'),
                  const SizedBox(height: CinevaSpacing.md),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sous-titres activés par défaut'),
                    value: settings.subtitlesEnabled,
                    onChanged: ref.read(settingsControllerProvider.notifier).updateSubtitles,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lecture automatique'),
                    value: settings.autoplayEnabled,
                    onChanged: ref.read(settingsControllerProvider.notifier).updateAutoplay,
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
