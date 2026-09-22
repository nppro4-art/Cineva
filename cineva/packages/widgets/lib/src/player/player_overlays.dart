import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:cineva_ui/cineva_ui.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'player_formatters.dart';

/// Contrôles du lecteur : paysage immersif, trois zones (haut, centre, bas)
/// posées sur des dégradés. Aucune bordure, aucun panneau Material : le
/// contenu reste dominant.
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
    this.titleOverride,
    this.locked = false,
    this.onToggleLock,
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

  /// Titre affiché (bande-annonce) — sinon [ContentDetailModel.title].
  final String? titleOverride;

  /// Commandes verrouillées : le bouton cadenas reste accessible.
  final bool locked;
  final VoidCallback? onToggleLock;

  /// État du Cineva Audio Engine (null → backend indisponible : pas de pill,
  /// on n'affiche jamais un traitement qui n'existe pas).
  final String? audioEngineLabel;
  final bool audioProcessing;
  final bool audioAbCompare;
  final VoidCallback? onOpenAudioSettings;
  final VoidCallback? onToggleAudioAb;

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? player = controller;
    final VideoPlayerController? activePlayer =
        player != null && player.value.isInitialized ? player : null;
    final bool initialized = activePlayer != null;
    final bool playing = activePlayer?.value.isPlaying ?? false;
    final int durationSeconds = activePlayer?.value.duration.inSeconds ?? 0;
    final int positionSeconds = activePlayer?.value.position.inSeconds ?? 0;
    final double progress = durationSeconds == 0
        ? 0.0
        : (positionSeconds / durationSeconds).clamp(0, 1).toDouble();
    final double buffered = _bufferedFraction(activePlayer, durationSeconds);

    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool compact = MediaQuery.sizeOf(context).height < 420;

    return Column(
      children: <Widget>[
        // ------------------------------------------------------------- haut
        Container(
          decoration: const BoxDecoration(gradient: CinevaScrims.playerTop),
          padding: EdgeInsets.fromLTRB(
            safe.left + CinevaSpacing.sm,
            safe.top + CinevaSpacing.xs,
            safe.right + CinevaSpacing.sm,
            CinevaSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              ControlButton(
                icon: Icons.arrow_back_rounded,
                size: 42,
                onTap: onBack,
                tooltip: 'Retour à la fiche',
              ),
              const SizedBox(width: CinevaSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      titleOverride ?? detail.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.cardTitle.copyWith(fontSize: 15.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        selectedAudio,
                        selectedSubtitle,
                        selectedQuality.preset.label,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CinevaTypography.meta.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CinevaSpacing.sm),
              if (onToggleLock != null) ...<Widget>[
                ControlButton(
                  icon: locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 42,
                  active: locked,
                  onTap: onToggleLock!,
                  tooltip: locked
                      ? 'Déverrouiller les commandes'
                      : 'Verrouiller les commandes',
                ),
                const SizedBox(width: CinevaSpacing.xs),
              ],
              ControlButton(
                icon: isImmersive
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                size: 42,
                onTap: onToggleImmersive,
                tooltip: isImmersive ? 'Quitter le plein écran' : 'Plein écran',
              ),
            ],
          ),
        ),

        // ----------------------------------------------------------- centre
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ControlButton(
                  icon: Icons.replay_10_rounded,
                  size: compact ? 46 : 54,
                  onTap: () => onSeek((progress - 0.05).clamp(0, 1).toDouble()),
                  tooltip: 'Reculer de 10 secondes',
                ),
                SizedBox(width: compact ? CinevaSpacing.lg : CinevaSpacing.xxl),
                _PlayPauseButton(playing: playing, onTap: onPlayPause),
                SizedBox(width: compact ? CinevaSpacing.lg : CinevaSpacing.xxl),
                ControlButton(
                  icon: Icons.forward_10_rounded,
                  size: compact ? 46 : 54,
                  onTap: () => onSeek((progress + 0.05).clamp(0, 1).toDouble()),
                  tooltip: 'Avancer de 10 secondes',
                ),
              ],
            ),
          ),
        ),

        // -------------------------------------------------------------- bas
        Container(
          decoration: const BoxDecoration(gradient: CinevaScrims.playerBottom),
          padding: EdgeInsets.fromLTRB(
            safe.left + CinevaSpacing.lg,
            CinevaSpacing.md,
            safe.right + CinevaSpacing.lg,
            safe.bottom + CinevaSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SizedBox(
                    height: 26,
                    child: Stack(
                      children: <Widget>[
                        if (buffered > progress)
                          Positioned(
                            left: 0,
                            top: 11.5,
                            width: constraints.maxWidth * buffered,
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0x40FFFFFF),
                                borderRadius:
                                    BorderRadius.circular(CinevaRadii.chip),
                              ),
                            ),
                          ),
                        CinevaSlider(
                          value: progress,
                          onChanged: initialized ? onSeek : null,
                          inactiveColor: const Color(0x24FFFFFF),
                          activeColor: CinevaColors.gold,
                          trackHeight: 3,
                          thumbSize: 13,
                          height: 26,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Text(
                    PlayerFormatters.formatDuration(positionSeconds),
                    style: CinevaTypography.numeric.copyWith(fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    '-${PlayerFormatters.formatDuration((durationSeconds - positionSeconds).clamp(0, durationSeconds))}',
                    style: CinevaTypography.numeric.copyWith(
                      fontSize: 11.5,
                      color: CinevaColors.textSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CinevaSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: CinevaSpacing.xs,
                      runSpacing: CinevaSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        PlayerPill(
                          icon: Icons.graphic_eq_rounded,
                          label: selectedAudio,
                          onTap: onOpenAudio,
                        ),
                        PlayerPill(
                          icon: Icons.closed_caption_rounded,
                          label: selectedSubtitle,
                          onTap: onOpenSubtitles,
                        ),
                        PlayerPill(
                          icon: Icons.high_quality_rounded,
                          label: selectedQuality.preset.label,
                          onTap: onOpenQuality,
                        ),
                        if (audioEngineLabel != null && onOpenAudioSettings != null)
                          PlayerPill(
                            icon: audioAbCompare
                                ? Icons.hearing_rounded
                                : Icons.graphic_eq_rounded,
                            label: audioAbCompare ? 'A/B' : audioEngineLabel!,
                            active: audioAbCompare || audioProcessing,
                            onTap: onOpenAudioSettings!,
                            tooltip:
                                'Cineva Audio — ${audioAbCompare ? 'son d’origine (B)' : (audioProcessing ? 'traitement actif' : 'en veille')}',
                          ),
                        if (audioEngineLabel != null && onToggleAudioAb != null)
                          ControlButton(
                            icon: audioAbCompare
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_rounded,
                            size: 34,
                            active: audioAbCompare,
                            onTap: onToggleAudioAb!,
                            tooltip: audioAbCompare
                                ? 'Revenir au son Cineva (A)'
                                : 'Comparer avec le son d’origine (B)',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CinevaSpacing.sm),
                  SizedBox(
                    width: compact ? 132 : 176,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          volume <= 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          size: 17,
                          color: CinevaColors.textSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: CinevaSlider(
                            value: volume,
                            onChanged: onVolumeChanged,
                            trackHeight: 3,
                            thumbSize: 11,
                            height: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Fraction déjà mise en mémoire tampon (jamais inventée : dérivée des
  /// plages réellement rapportées par le lecteur).
  double _bufferedFraction(VideoPlayerController? player, int durationSeconds) {
    if (player == null || durationSeconds <= 0) return 0;
    final List<DurationRange> ranges = player.value.buffered;
    if (ranges.isEmpty) return 0;
    int best = 0;
    for (final DurationRange range in ranges) {
      final int end = range.end.inSeconds;
      if (end > best) best = end;
    }
    return (best / durationSeconds).clamp(0, 1).toDouble();
  }
}

/// Bouton de lecture principal : disque doré, icône sombre, appui élastique.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Lecture',
      child: CinevaPressable(
        pressedScale: 0.9,
        onTap: onTap,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CinevaColors.gold.withOpacity(0.94),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: CinevaColors.goldGlow,
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: CinevaMotion.fast,
            switchInCurve: CinevaCurve.release,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey<bool>(playing),
              size: 34,
              color: CinevaColors.textOnLight,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton circulaire translucide des contrôles.
class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 56,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = CinevaPressable(
      pressedScale: 0.9,
      onTap: onTap,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? CinevaColors.gold.withOpacity(0.18)
              : const Color(0x1AFFFFFF),
        ),
        child: Icon(
          icon,
          size: size * 0.44,
          color: active ? CinevaColors.goldBright : CinevaColors.textHigh,
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 400),
      child: button,
    );
  }
}

/// Pill de réglage (audio, sous-titres, qualité, moteur audio).
class PlayerPill extends StatelessWidget {
  const PlayerPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? CinevaColors.goldBright : CinevaColors.textHigh;

    final Widget pill = CinevaPressable(
      pressedScale: 0.94,
      onTap: onTap,
      semanticLabel: tooltip ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? CinevaColors.gold.withOpacity(0.14) : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(CinevaRadii.chip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 168),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CinevaTypography.button.copyWith(fontSize: 12, color: color),
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null) return pill;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 400),
      child: pill,
    );
  }
}

/// Pill d'action contextuelle (ignorer l'intro, passer un segment…).
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CinevaPressable(
      pressedScale: 0.95,
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: CinevaColors.gold,
          borderRadius: BorderRadius.circular(CinevaRadii.chip),
          boxShadow: CinevaShadows.player,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: CinevaColors.textOnLight),
            const SizedBox(width: 7),
            Text(
              label,
              style: CinevaTypography.button.copyWith(
                fontSize: 12.5,
                color: CinevaColors.textOnLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Retour visuel de geste (volume, luminosité, seek).
class GestureToast extends StatelessWidget {
  const GestureToast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(CinevaRadii.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CinevaColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte « épisode suivant » : surface modale sombre, compte à rebours doré.
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
      width: 330,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.modal.withOpacity(0.96),
          borderRadius: BorderRadius.circular(CinevaRadii.large),
          boxShadow: CinevaShadows.modal,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CinevaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'ÉPISODE SUIVANT',
                    style: CinevaTypography.overline.copyWith(color: CinevaColors.gold),
                  ),
                  const Spacer(),
                  Text(
                    '$countdown s',
                    style: CinevaTypography.numeric.copyWith(
                      fontSize: 15,
                      color: CinevaColors.goldBright,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CinevaSpacing.sm),
              CinevaProgressBar(
                value: countdown <= 0 ? 0 : (10 - countdown) / 10,
                height: 2.5,
              ),
              const SizedBox(height: CinevaSpacing.sm),
              Text(
                'La lecture continue automatiquement. Vous pouvez lancer immédiatement ou annuler.',
                style: CinevaTypography.bodyCompact.copyWith(fontSize: 12),
              ),
              const SizedBox(height: CinevaSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CinevaPlayButton(
                      label: 'Lire maintenant',
                      icon: Icons.skip_next_rounded,
                      height: 42,
                      onPressed: onPlayNow,
                    ),
                  ),
                  const SizedBox(width: CinevaSpacing.xs),
                  ControlButton(
                    icon: Icons.close_rounded,
                    size: 42,
                    onTap: onDismiss,
                    tooltip: 'Annuler la lecture automatique',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
