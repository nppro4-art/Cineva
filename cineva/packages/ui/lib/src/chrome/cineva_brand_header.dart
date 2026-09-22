import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';

import '../primitives/cineva_pressable.dart';

/// Wordmark CINEVA : typographie fine/moyenne, letter-spacing important.
class CinevaWordmark extends StatelessWidget {
  const CinevaWordmark({
    super.key,
    this.style = CinevaTypography.brand,
    this.onTap,
    this.color,
  });

  final TextStyle style;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(
      'CINEVA',
      style: style.copyWith(color: color ?? style.color),
    );
    if (onTap == null) return text;
    return CinevaPressable(pressedScale: 0.96, onTap: onTap, semanticLabel: 'Cineva', child: text);
  }
}

/// En-tête de l'accueil : CINEVA à gauche, recherche et profil à droite.
///
/// [opacity] pilote la transition « transparent → surface sombre » : le fond
/// et le liseré inférieur apparaissent progressivement pendant le scroll,
/// sans jamais d'à-coup.
class CinevaBrandHeader extends StatelessWidget {
  const CinevaBrandHeader({
    super.key,
    required this.onSearch,
    required this.onProfile,
    this.opacity = 0,
    this.avatar,
    this.topInset = 0,
    this.height = 52,
  });

  final VoidCallback onSearch;
  final VoidCallback onProfile;

  /// 0 = header transparent (posé sur le hero), 1 = surface sombre pleine.
  final double opacity;

  /// Avatar du profil (sinon initiale dérivée du libellé).
  final Widget? avatar;
  final double topInset;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double o = opacity.clamp(0.0, 1.0).toDouble();

    return RepaintBoundary(
      child: Container(
        height: height + topInset,
        padding: EdgeInsets.only(top: topInset, left: CinevaSpacing.lg, right: CinevaSpacing.sm),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(Colors.transparent, CinevaColors.surface, o)!,
              Color.lerp(Colors.transparent, CinevaColors.surface.withOpacity(0.92), o)!,
            ],
          ),
          border: o > 0.98 ? const Border(bottom: CinevaEdges.hairlineTop) : null,
        ),
        child: Row(
          children: <Widget>[
            const CinevaWordmark(),
            const Spacer(),
            _HeaderAction(
              icon: Icons.search_rounded,
              tooltip: 'Recherche',
              onTap: onSearch,
            ),
            const SizedBox(width: CinevaSpacing.xs),
            CinevaPressable(
              pressedScale: 0.9,
              onTap: onProfile,
              semanticLabel: 'Mon profil',
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: avatar ?? const _DefaultAvatar(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = CinevaPressable(
      pressedScale: 0.9,
      onTap: onTap,
      semanticLabel: tooltip,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(icon, size: 22, color: CinevaColors.textHigh),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Avatar par défaut : initiale sur une surface élevée, liseré doré discret.
class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CinevaColors.raised,
        border: Border.all(color: CinevaColors.hairlineStrong),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, size: 17, color: CinevaColors.textSoft),
    );
  }
}

/// Avatar de profil réutilisable (header, page profil, sélecteur de profils).
class CinevaAvatar extends StatelessWidget {
  const CinevaAvatar({
    super.key,
    this.imagePath,
    this.initials,
    this.size = 40,
    this.onTap,
    this.ring = false,
  });

  final String? imagePath;
  final String? initials;
  final double size;
  final VoidCallback? onTap;

  /// Anneau doré (profil actif).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CinevaColors.raised,
        border: Border.all(
          color: ring ? CinevaColors.gold.withOpacity(0.7) : CinevaColors.hairlineStrong,
          width: ring ? 1.6 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: _avatarChild(),
    );

    if (onTap == null) return content;
    return CinevaPressable(
      pressedScale: 0.92,
      onTap: onTap,
      semanticLabel: initials == null ? 'Profil' : 'Profil $initials',
      child: content,
    );
  }

  Widget _avatarChild() {
    final String path = imagePath ?? '';
    final bool isRemote = path.startsWith('http://') || path.startsWith('https://');
    final bool usable = path.isNotEmpty && !path.startsWith('demo://');

    if (usable && isRemote) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
            _fallback(),
      );
    }
    if (usable) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
            _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final String label = (initials ?? '').trim();
    if (label.isEmpty) {
      return Icon(Icons.person_rounded, size: size * 0.5, color: CinevaColors.textSoft);
    }
    return Text(
      label.length > 2 ? label.substring(0, 2) : label,
      style: CinevaTypography.cardTitle.copyWith(
        fontSize: size * 0.36,
        color: CinevaColors.textHigh,
      ),
    );
  }
}
