import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../audio/audio_engine_controller.dart';
import '../vision/vision_controller.dart';
import 'settings_controller.dart';
import 'settings_scaffold.dart';

/// Audio & Vidéo (route `/settings/audio-video`).
///
/// Regroupe les préférences de lecture réellement persistées :
/// qualité vidéo globale, sous-titres, lecture automatique, moteur audio
/// Cineva (profil, dialogues, basses, spatialisation, loudness) et accès
/// aux réglages avancés. Remplace l'ancien écran « Préférences vidéo ».
class AudioVideoScreen extends ConsumerWidget {
  const AudioVideoScreen({super.key});

  static const List<String> qualityValues = <String>[
    'auto',
    '480p',
    '720p',
    '1080p',
    '1440p',
    '4k',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SettingsController settingsController =
        ref.read(settingsControllerProvider.notifier);
    final AppSettingsModel settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? AppSettingsModel.defaults();

    final AudioEngineController audioController =
        ref.read(audioEngineControllerProvider.notifier);
    final AudioEngineUiState audio = ref.watch(audioEngineControllerProvider);
    final CinevaAudioSettings audioSettings = audio.settings;

    final VisionState vision = ref.watch(visionControllerProvider);
    final String recommended = vision.capabilities?.recommendedModeLabel ?? 'Analyse en cours';
    final String visionProfile = vision.settings?.profile.label ?? settings.visionSettings.profile.label;

    final CinevaMetrics metrics = CinevaMetrics.of(context);

    return Scaffold(
      backgroundColor: CinevaColors.ink,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
          decelerationRate: ScrollDecelerationRate.fast,
        ),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: CinevaTopBar(
              title: 'Audio & Vidéo',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              metrics.gutter,
              CinevaSpacing.sm,
              metrics.gutter,
              CinevaSpacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[
                  Text('Lecture', style: CinevaTypography.screenTitle.copyWith(fontSize: 21)),
                  const SizedBox(height: CinevaSpacing.xs),
                  Text(
                    'Ces réglages s’appliquent à toutes vos lectures, sur cet appareil.',
                    style: CinevaTypography.bodyCompact,
                  ),
                  const SizedBox(height: CinevaSpacing.xl),

                  // --------------------------------------------------- vidéo
                  const CinevaSectionHeader(title: 'Qualité vidéo'),
                  Wrap(
                    spacing: CinevaSpacing.xs,
                    runSpacing: CinevaSpacing.xs,
                    children: qualityValues
                        .map(
                          (String quality) => CinevaChip(
                            label: quality == 'auto' ? 'Auto' : quality.toUpperCase(),
                            selected: settings.videoQuality == quality,
                            onSelected: (_) =>
                                settingsController.updateVideoQuality(quality),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.sm),
                  Text(
                    'Mode recommandé pour cet appareil : $recommended',
                    style: CinevaTypography.meta.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),

                  // -------------------------------------------------- image
                  const CinevaSectionHeader(title: 'Image'),
                  SettingsGroup(
                    children: <Widget>[
                      CinevaListTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Cineva Vision',
                        subtitle: visionProfile,
                        onTap: () => context.push('/settings/cineva-vision'),
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.md),

                  // --------------------------------------------- comportement
                  const CinevaSectionHeader(title: 'Comportement'),
                  SettingsGroup(
                    children: <Widget>[
                      CinevaSwitchTile(
                        icon: Icons.closed_caption_rounded,
                        title: 'Sous-titres par défaut',
                        subtitle: 'Affichés au démarrage de chaque lecture',
                        value: settings.subtitlesEnabled,
                        onChanged: settingsController.updateSubtitles,
                      ),
                      const CinevaHairline(indent: 52),
                      CinevaSwitchTile(
                        icon: Icons.skip_next_rounded,
                        title: 'Lecture automatique',
                        subtitle: 'Enchaîne sur l’épisode suivant',
                        value: settings.autoplayEnabled,
                        onChanged: settingsController.updateAutoplay,
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.xl),

                  // -------------------------------------------------- audio
                  const CinevaSectionHeader(title: 'Moteur audio Cineva'),
                  SettingsGroup(
                    children: <Widget>[
                      CinevaSwitchTile(
                        icon: Icons.graphic_eq_rounded,
                        title: 'Activer le moteur audio',
                        subtitle: audio.backendAvailable
                            ? (audio.processingActive
                                ? 'Traitement actif'
                                : (audioSettings.enabled
                                    ? 'En veille — aucun média branché'
                                    : 'Désactivé'))
                            : 'Indisponible sur cet appareil — le son d’origine est conservé',
                        value: audioSettings.enabled,
                        onChanged: audioController.updateEnabled,
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  const CinevaSectionHeader(title: 'Profil sonore'),
                  ...CinevaAudioProfile.values.map(
                    (CinevaAudioProfile profile) => Padding(
                      padding: const EdgeInsets.only(bottom: CinevaSpacing.xs),
                      child: _ProfileRow(
                        profile: profile,
                        selected: audioSettings.profile == profile,
                        enabled: audioSettings.enabled,
                        onTap: () => audioController.updateProfile(profile),
                      ),
                    ),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  const CinevaSectionHeader(title: 'Réglages'),
                  SettingsGroup(
                    children: <Widget>[
                      CinevaSliderTile(
                        icon: Icons.record_voice_over_outlined,
                        label: 'Clarté des dialogues',
                        value: audioSettings.dialogueAmount,
                        enabled: audioSettings.enabled,
                        onChanged: audioController.updateDialogueAmount,
                      ),
                      CinevaSliderTile(
                        icon: Icons.speaker_rounded,
                        label: 'Profondeur des basses',
                        value: audioSettings.bassAmount,
                        enabled: audioSettings.enabled,
                        onChanged: audioController.updateBassAmount,
                      ),
                      const CinevaHairline(indent: 20),
                      CinevaSwitchTile(
                        icon: Icons.surround_sound_rounded,
                        title: 'Spatialisation',
                        subtitle: audioSettings.output == CinevaAudioOutput.headphone
                            ? 'Rendu binaural pour le casque'
                            : 'Élargissement de la scène sonore',
                        value: audioSettings.spatialEnabled,
                        enabled: audioSettings.enabled,
                        onChanged: audioController.updateSpatial,
                      ),
                      const CinevaHairline(indent: 52),
                      CinevaSwitchTile(
                        icon: Icons.volume_up_rounded,
                        title: 'Normalisation du volume',
                        subtitle: 'Niveau constant d’un contenu à l’autre',
                        value: audioSettings.loudnessEnabled,
                        enabled: audioSettings.enabled,
                        onChanged: audioController.updateLoudness,
                      ),
                      const CinevaHairline(indent: 52),
                      CinevaSwitchTile(
                        icon: Icons.swap_horiz_rounded,
                        title: 'Comparer avec le son d’origine',
                        subtitle: 'Bypass instantané du moteur (A/B)',
                        value: audioSettings.abCompare,
                        enabled: audioSettings.enabled,
                        onChanged: (_) => audioController.toggleAbCompare(),
                      ),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  const CinevaSectionHeader(title: 'Dynamique'),
                  Wrap(
                    spacing: CinevaSpacing.xs,
                    runSpacing: CinevaSpacing.xs,
                    children: CinevaAudioDynamicRange.values
                        .map(
                          (CinevaAudioDynamicRange range) => CinevaChip(
                            label: range.label,
                            selected: audioSettings.dynamicRange == range,
                            onSelected: (_) =>
                                audioController.updateDynamicRange(range),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.lg),
                  const CinevaSectionHeader(title: 'Sortie audio'),
                  Wrap(
                    spacing: CinevaSpacing.xs,
                    runSpacing: CinevaSpacing.xs,
                    children: CinevaAudioOutput.values
                        .map(
                          (CinevaAudioOutput output) => CinevaChip(
                            label: output.label,
                            selected: audioSettings.output == output,
                            onSelected: (_) => audioController.updateOutput(output),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: CinevaSpacing.xl),
                  CinevaSecondaryButton(
                    label: 'Réglages avancés',
                    icon: Icons.tune_rounded,
                    height: 46,
                    onPressed: () => context.push('/settings/audio/advanced'),
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  Text(
                    'Dynamique, sortie audio, égaliseur, crossover et limiteur.',
                    style: CinevaTypography.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Profil audio : libellé, description, sélection radio dorée.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.profile,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final CinevaAudioProfile profile;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? CinevaColors.gold : CinevaColors.textFaint;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: CinevaPressable(
        pressedScale: 0.99,
        enabled: enabled,
        onTap: onTap,
        semanticLabel: 'Profil ${profile.label}',
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? CinevaColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(CinevaRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CinevaSpacing.md,
              vertical: CinevaSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: CinevaSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        profile.label,
                        style: CinevaTypography.cardTitle.copyWith(
                          fontSize: 14,
                          color: selected ? CinevaColors.textHigh : CinevaColors.textSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile.description,
                        style: CinevaTypography.bodyCompact.copyWith(fontSize: 11.5),
                      ),
                    ],
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
