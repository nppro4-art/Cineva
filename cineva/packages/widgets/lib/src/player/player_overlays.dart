import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'player_formatters.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.detail,
    required this.controller,
    required this.volume,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.selectedQuality,
    required this.isImmersive,
    required this.onBack,
    required this.onPlayPause,
    required this.onSeek,
    required this.onToggleImmersive,
    required this.onOpenAudio,
    required this.onOpenSubtitles,
    required this.onOpenQuality,
    required this.onVolumeChanged,
    this.audioEngineLabel,
    this.audioProcessing = false,
    this.audioAbCompare = false,
    this.onOpenAudioSettings,
    this.onToggleAudioAb,
  });

  final ContentDetailModel detail;
  final VideoPlayerController? controller;
  final double volume;
  final String selectedAudio;
  final String selectedSubtitle;
  final VideoQualityOption selectedQuality;
  final bool isImmersive;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onToggleImmersive;
  final VoidCallback onOpenAudio;
  final VoidCallback onOpenSubtitles;
  final VoidCallback onOpenQuality;
  final ValueChanged<double> onVolumeChanged;

  /// État du Cineva Audio Engine (null → backend indisponible : pas de pill,
  /// on n'affiche jamais un traitement qui n'existe pas).
  final String? audioEngineLabel;
  final bool audioProcessing;
  final bool audioAbCompare;
  final VoidCallback? onOpenAudioSettings;
  final VoidCallback? onToggleAudioAb;

  @override
  Widget build(BuildContext context) {
    final player = controller;
    final activePlayer = player != null && player.value.isInitialized ? player : null;
    final initialized = activePlayer != null;
    final playing = activePlayer?.value.isPlaying ?? false;
    final durationSeconds = activePlayer?.value.duration.inSeconds ?? 0;
    final positionSeconds = activePlayer?.value.position.inSeconds ?? 0;
    final progress = durationSeconds == 0 ? 0.0 : (positionSeconds / durationSeconds).clamp(0, 1).toDouble();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CinevaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: CinevaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(detail.title, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedAudio • $selectedSubtitle • ${selectedQuality.preset.label}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onToggleImmersive,
                  icon: Icon(isImmersive ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ControlButton(icon: Icons.replay_10_rounded, onTap: () => onSeek((progress - 0.05).clamp(0, 1).toDouble())),
                  const SizedBox(width: CinevaSpacing.md),
                  ControlButton(
                    icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 72,
                    onTap: onPlayPause,
                  ),
                  const SizedBox(width: CinevaSpacing.md),
                  ControlButton(icon: Icons.forward_10_rounded, onTap: () => onSeek((progress + 0.05).clamp(0, 1).toDouble())),
                ],
              ),
            ),
            const Spacer(),
            CinevaGlassCard(
              child: Column(
                children: <Widget>[
                  Slider(value: progress, onChanged: initialized ? onSeek : null),
                  Row(
                    children: <Widget>[
                      Text(PlayerFormatters.formatDuration(positionSeconds)),
                      const Spacer(),
                      Text(PlayerFormatters.formatDuration(durationSeconds)),
                    ],
                  ),
                  const SizedBox(height: CinevaSpacing.md),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: onOpenAudio,
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: Text(selectedAudio),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenSubtitles,
                        icon: const Icon(Icons.subtitles_rounded),
                        label: Text(selectedSubtitle),
                      ),
                      OutlinedButton.icon(
                        onPressed: onOpenQuality,
                        icon: const Icon(Icons.high_quality_rounded),
                        label: Text(selectedQuality.preset.label),
                      ),
                      if (audioEngineLabel != null && onOpenAudioSettings != null)
                        Tooltip(
                          message: 'Cineva Audio — ${audioAbCompare ? 'son d\'origine (B)' : (audioProcessing ? 'traitement actif' : 'en veille')}',
                          child: OutlinedButton.icon(
                            onPressed: onOpenAudioSettings,
                            icon: Icon(
                              audioAbCompare
                                  ? Icons.hearing_rounded
                                  : Icons.graphic_eq_rounded,
                              color: audioAbCompare || audioProcessing
                                  ? CinevaColors.accentSoft
                                  : null,
                            ),
                            label: Text(audioAbCompare ? 'A/B' : audioEngineLabel!),
                          ),
                        ),
                      if (audioEngineLabel != null && onToggleAudioAb != null)
                        IconButton.filledTonal(
                          tooltip: audioAbCompare
                              ? 'Revenir au son Cineva (A)'
                              : 'Comparer avec le son d\'origine (B)',
                          onPressed: onToggleAudioAb,
                          icon: Icon(
                            audioAbCompare ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                            color: audioAbCompare ? CinevaColors.accentSoft : null,
                          ),
                        ),
                      SizedBox(
                        width: 240,
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.volume_up_rounded),
                            Expanded(child: Slider(value: volume, onChanged: onVolumeChanged)),
                          ],
                        ),
                      ),
                    ],
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

class ControlButton extends StatelessWidget {
  const ControlButton({super.key, required this.icon, required this.onTap, this.size = 56});

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.45),
        ),
      ),
    );
  }
}

class ActionPill extends StatelessWidget {
  const ActionPill({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class GestureToast extends StatelessWidget {
  const GestureToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Text(message, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class NextEpisodeCard extends StatelessWidget {
  const NextEpisodeCard({
    super.key,
    required this.countdown,
    required this.onPlayNow,
    required this.onDismiss,
  });

  final int countdown;
  final VoidCallback onPlayNow;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: CinevaGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Épisode suivant dans $countdown sec', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CinevaSpacing.sm),
            Text(
              'La lecture continue automatiquement. Vous pouvez lancer immédiatement ou annuler.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: CinevaColors.textMuted),
            ),
            const SizedBox(height: CinevaSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: CinevaPrimaryButton(
                    label: 'Lire maintenant',
                    icon: Icons.skip_next_rounded,
                    onPressed: onPlayNow,
                  ),
                ),
                const SizedBox(width: CinevaSpacing.sm),
                IconButton(onPressed: onDismiss, icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
