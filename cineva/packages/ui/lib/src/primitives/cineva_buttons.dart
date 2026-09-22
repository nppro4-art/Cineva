import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import 'cineva_pressable.dart';

/// Bouton principal « ▶ Regarder ».
///
/// Fond clair, texte sombre, icône de lecture, lisibilité maximale.
/// Un halo doré respire très lentement (3,6 s) pour signaler l'action
/// principale sans jamais pulser de façon agressive. L'animation est coupée
/// si l'utilisateur a demandé la réduction des animations du système.
class CinevaPlayButton extends StatefulWidget {
  const CinevaPlayButton({
    super.key,
    required this.onPressed,
    this.label = 'Regarder',
    this.icon = Icons.play_arrow_rounded,
    this.expanded = true,
    this.isLoading = false,
    this.height = 50,
    this.semanticLabel,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  /// Prend toute la largeur disponible (sinon se cale sur le contenu).
  final bool expanded;
  final bool isLoading;
  final double height;
  final String? semanticLabel;

  @override
  State<CinevaPlayButton> createState() => _CinevaPlayButtonState();
}

class _CinevaPlayButtonState extends State<CinevaPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _syncGlow();
    }
  }

  @override
  void didUpdateWidget(CinevaPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPressed != widget.onPressed || oldWidget.isLoading != widget.isLoading) {
      _syncGlow();
    }
  }

  void _syncGlow() {
    final bool shouldBreath = !_reduceMotion && widget.onPressed != null && !widget.isLoading;
    if (shouldBreath && !_glow.isAnimating) {
      _glow.repeat(reverse: true);
      return;
    }
    if (!shouldBreath && _glow.isAnimating) {
      _glow.stop();
      _glow.value = 0;
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;

    final Widget content = AnimatedSwitcher(
      duration: CinevaMotion.medium,
      switchInCurve: CinevaCurve.out,
      switchOutCurve: CinevaCurve.inOut,
      transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: widget.isLoading
          ? SizedBox(
              key: const ValueKey<String>('loading'),
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: CinevaColors.textOnLight.withOpacity(0.8),
              ),
            )
          : Row(
              key: ValueKey<String>('content-${widget.label}'),
              mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: 22, color: CinevaColors.textOnLight),
                  const SizedBox(width: CinevaSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CinevaTypography.button,
                  ),
                ),
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      child: CinevaPressable(
        enabled: enabled,
        pressedScale: 0.96,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (BuildContext context, Widget? child) {
            final double glow = _reduceMotion ? 0.24 : 0.20 + (_glow.value * 0.14);
            return Container(
              height: widget.height,
              width: widget.expanded ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.lg),
              decoration: BoxDecoration(
                color: enabled ? CinevaColors.textHigh : CinevaColors.raised,
                borderRadius: BorderRadius.circular(CinevaRadii.medium),
                boxShadow: enabled
                    ? CinevaShadows.goldGlow(opacity: glow)
                    : const <BoxShadow>[],
              ),
              alignment: Alignment.center,
              child: DefaultTextStyle(
                style: CinevaTypography.button.copyWith(
                  color: enabled ? CinevaColors.textOnLight : CinevaColors.textFaint,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: enabled ? CinevaColors.textOnLight : CinevaColors.textFaint,
                    size: 22,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: content,
        ),
      ),
    );
  }
}

/// Bouton secondaire : surface sombre élevée, liseré discret, texte clair.
class CinevaSecondaryButton extends StatelessWidget {
  const CinevaSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.height = 50,
    this.tone = CinevaButtonTone.neutral,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final double height;
  final CinevaButtonTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color foreground = switch (tone) {
      CinevaButtonTone.neutral => CinevaColors.textHigh,
      CinevaButtonTone.gold => CinevaColors.gold,
      CinevaButtonTone.danger => CinevaColors.danger,
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      child: CinevaPressable(
        enabled: enabled,
        pressedScale: 0.96,
        onTap: onPressed,
        child: Container(
          height: height,
          width: expanded ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: CinevaSpacing.lg),
          decoration: BoxDecoration(
            color: CinevaColors.raised.withOpacity(enabled ? 0.92 : 0.5),
            borderRadius: BorderRadius.circular(CinevaRadii.medium),
            border: Border.all(color: CinevaColors.hairline),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: CinevaSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CinevaTypography.button.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum CinevaButtonTone { neutral, gold, danger }

/// Action circulaire avec libellé dessous (Bande-annonce, Ma liste, Télécharger).
class CinevaCircleAction extends StatelessWidget {
  const CinevaCircleAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
    this.size = 52,
    this.progress,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// État actif (dans ma liste, téléchargé…) : liseré doré.
  final bool active;

  final double size;

  /// Progression annulaire (téléchargement en cours), de 0 à 1.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color foreground = active ? CinevaColors.gold : CinevaColors.textHigh;

    final Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CinevaColors.raised.withOpacity(enabled ? 0.88 : 0.5),
        border: Border.all(
          color: active ? CinevaColors.gold.withOpacity(0.55) : CinevaColors.hairlineStrong,
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: CinevaMotion.fast,
          switchInCurve: CinevaCurve.release,
          transitionBuilder: (Widget child, Animation<double> animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(icon, key: ValueKey<IconData>(icon), size: size * 0.42, color: foreground),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CinevaPressable(
            enabled: enabled,
            pressedScale: 0.92,
            onTap: onPressed,
            child: progress == null
                ? circle
                : SizedBox(
                    width: size + 6,
                    height: size + 6,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: size + 6,
                          height: size + 6,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(CinevaColors.gold),
                          ),
                        ),
                        circle,
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: CinevaSpacing.xs),
          SizedBox(
            width: size + 34,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: CinevaTypography.meta.copyWith(
                fontSize: 11,
                color: active ? CinevaColors.gold : CinevaColors.textSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton icône fantôme rond (retour, recherche, profil, plus…).
class CinevaIconButton extends StatelessWidget {
  const CinevaIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.filled = true,
    this.foreground,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  /// Fond sombre translucide (sur image) ou totalement transparent.
  final bool filled;
  final Color? foreground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget button = CinevaPressable(
      enabled: enabled,
      pressedScale: 0.9,
      onTap: onPressed,
      semanticLabel: semanticLabel ?? tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? CinevaColors.overlay.withOpacity(enabled ? 0.78 : 0.4) : null,
          border: filled ? null : Border.all(color: CinevaColors.hairline),
        ),
        child: Icon(
          icon,
          size: size * 0.52,
          color: foreground ?? (enabled ? CinevaColors.textHigh : CinevaColors.textFaint),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
