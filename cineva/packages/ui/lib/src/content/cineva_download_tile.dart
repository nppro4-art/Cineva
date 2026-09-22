import 'package:cineva_models/cineva_models.dart';
import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_pressable.dart';
import '../primitives/cineva_progress.dart';
import 'cineva_artwork_image.dart';
import 'cineva_content_labels.dart';

/// Ligne de téléchargement : affiche, titre, qualité · taille, progression,
/// action (pause / reprise / suppression) et confirmation à la fin.
class CinevaDownloadTile extends StatelessWidget {
  const CinevaDownloadTile({
    super.key,
    required this.item,
    this.onTap,
    this.onPrimaryAction,
    this.onRemove,
    this.primaryIcon,
    this.primaryTooltip,
  });

  final DownloadItemModel item;

  /// Ouvre la fiche (ou lance la lecture si le fichier est disponible).
  final VoidCallback? onTap;

  /// Pause / reprise / relance.
  final VoidCallback? onPrimaryAction;

  final VoidCallback? onRemove;

  /// Icône de l'action principale (calculée par l'écran selon le statut).
  final IconData? primaryIcon;
  final String? primaryTooltip;

  @override
  Widget build(BuildContext context) {
    final ContentTileModel content = item.content;
    final List<String> tokens = CinevaContentLabels.qualityTokens(content.badge);
    final String quality = tokens.isEmpty
        ? CinevaContentLabels.type(content.contentType)
        : tokens.first;
    final String size = item.totalBytes > 0
        ? CinevaSizeLabels.fromBytes(item.totalBytes)
        : CinevaSizeLabels.fromMb(item.sizeMb);
    final bool completed = item.isCompleted;
    final bool failed = item.status == DownloadStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: CinevaSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CinevaColors.surface,
          borderRadius: BorderRadius.circular(CinevaRadii.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CinevaRadii.card),
          child: CinevaPressable(
            pressedScale: 0.99,
            onTap: onTap,
            semanticLabel: content.title,
            child: Padding(
              padding: const EdgeInsets.all(CinevaSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 58,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CinevaRadii.small),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CinevaArtworkImage.forTile(content),
                            if (completed)
                              const DecoratedBox(
                                decoration: BoxDecoration(color: Color(0x59000000)),
                                child: Center(
                                  child: Icon(
                                    Icons.download_done_rounded,
                                    size: 20,
                                    color: CinevaColors.gold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: CinevaSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CinevaTypography.cardTitle.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          <String>[quality, if (size.isNotEmpty) size]
                              .where((String value) => value.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CinevaTypography.meta.copyWith(fontSize: 11.5),
                        ),
                        if (!completed) ...<Widget>[
                          const SizedBox(height: 8),
                          CinevaProgressBar(
                            value: item.progressPercent,
                            height: 3,
                            activeColor: failed ? CinevaColors.warning : CinevaColors.gold,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusLine(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CinevaTypography.numeric.copyWith(
                              fontSize: 11,
                              color: failed ? CinevaColors.warning : CinevaColors.textFaint,
                            ),
                          ),
                        ] else ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            item.canPlayOffline ? 'Disponible hors ligne' : 'Fichier indisponible',
                            style: CinevaTypography.meta.copyWith(
                              fontSize: 11.5,
                              color: item.canPlayOffline
                                  ? CinevaColors.success
                                  : CinevaColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: CinevaSpacing.xs),
                  _tileActions(completed),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileActions(bool completed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedSwitcher(
          duration: CinevaMotion.medium,
          switchInCurve: CinevaCurve.release,
          transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: completed
              ? _TileIconButton(
                  key: const ValueKey<String>('done'),
                  icon: Icons.play_circle_outline_rounded,
                  color: CinevaColors.gold,
                  tooltip: 'Lire hors ligne',
                  onPressed: onTap,
                )
              : _TileIconButton(
                  key: ValueKey<IconData?>(primaryIcon),
                  icon: primaryIcon ?? Icons.pause_rounded,
                  tooltip: primaryTooltip,
                  onPressed: onPrimaryAction,
                ),
        ),
        if (onRemove != null) ...<Widget>[
          const SizedBox(height: 2),
          _TileIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Retirer',
            onPressed: onRemove,
            size: 16,
          ),
        ],
      ],
    );
  }

  String _statusLine(DownloadItemModel item) {
    final List<String> parts = <String>[
      '${(item.progressPercent * 100).round()} %',
      if (item.transferSpeedMbps != null && item.transferSpeedMbps! > 0)
        '${item.transferSpeedMbps!.toStringAsFixed(1).replaceAll('.', ',')} Mb/s',
      if (item.estimatedRemainingSeconds != null && item.estimatedRemainingSeconds! > 0)
        'encore ${_eta(item.estimatedRemainingSeconds!)}',
      if (item.downloadedBytes > 0 && item.totalBytes > 0)
        '${CinevaSizeLabels.fromBytes(item.downloadedBytes)} / ${CinevaSizeLabels.fromBytes(item.totalBytes)}',
    ];
    if (item.status == DownloadStatus.paused && parts.isNotEmpty) {
      return 'En pause · ${parts.first}';
    }
    if (item.status == DownloadStatus.queued) return 'En file d’attente';
    if (item.status == DownloadStatus.failed) {
      return item.errorMessage ?? 'Échec du téléchargement';
    }
    return parts.join(' · ');
  }

  static String _eta(int seconds) {
    if (seconds < 60) return '$seconds s';
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    return '$minutes min ${rest.toString().padLeft(2, '0')} s';
  }
}

class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 19,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget button = CinevaPressable(
      pressedScale: 0.86,
      enabled: onPressed != null,
      onTap: onPressed,
      semanticLabel: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: size, color: color ?? CinevaColors.textSoft),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
