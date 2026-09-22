import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_pressable.dart';

/// Interrupteur Cineva : piste sombre, pommeau clair, or à l'activation.
///
/// Le déplacement du pommeau est animé en [CinevaMotion.fast] avec
/// [CinevaCurve.release] (léger dépassement), la piste en fondu.
class CinevaSwitch extends StatelessWidget {
  const CinevaSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;

  /// `null` désactive l'interrupteur.
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  static const double _width = 46;
  static const double _height = 27;
  static const double _thumb = 21;

  @override
  Widget build(BuildContext context) {
    final bool interactive = enabled && onChanged != null;
    final double opacity = interactive ? 1 : 0.45;

    return Opacity(
      opacity: opacity,
      child: Semantics(
        toggled: value,
        enabled: interactive,
        child: CinevaPressable(
          enabled: interactive,
          pressedScale: 0.94,
          haptic: false,
          onTap: interactive ? () => onChanged!(!value) : null,
          child: SizedBox(
            width: _width,
            height: _height,
            child: Stack(
              children: <Widget>[
                AnimatedContainer(
                  duration: CinevaMotion.fast,
                  curve: CinevaCurve.out,
                  decoration: BoxDecoration(
                    color: value ? CinevaColors.gold : CinevaColors.raised,
                    borderRadius: BorderRadius.circular(CinevaRadii.chip),
                    border: Border.all(
                      color: value ? Colors.transparent : CinevaColors.hairlineStrong,
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: CinevaMotion.fast,
                  curve: CinevaCurve.release,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: value ? CinevaColors.textOnLight : CinevaColors.textSoft,
                        shape: BoxShape.circle,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Largeur fixe réservée (utile pour aligner des lignes de réglages).
  static double get width => _width;
}

/// Ligne de réglage : titre, sous-titre optionnel et [CinevaSwitch] à droite.
class CinevaSwitchTile extends StatelessWidget {
  const CinevaSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CinevaSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 19, color: CinevaColors.textSoft),
            const SizedBox(width: CinevaSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: CinevaTypography.cardTitle.copyWith(
                    fontSize: 14.5,
                    color: enabled ? CinevaColors.textHigh : CinevaColors.textFaint,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: CinevaTypography.bodyCompact.copyWith(fontSize: 12.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: CinevaSpacing.sm),
          CinevaSwitch(value: value, onChanged: onChanged, enabled: enabled),
        ],
      ),
    );
  }
}
