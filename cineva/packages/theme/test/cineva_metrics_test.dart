import 'package:cineva_theme/cineva_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CinevaMetrics metrics({
  required double width,
  required double height,
  double topInset = 0,
  double bottomInset = 0,
}) {
  return CinevaMetrics(
    width: width,
    height: height,
    topInset: topInset,
    bottomInset: bottomInset,
    textScale: 1,
  );
}

void main() {
  group('CinevaMetrics — classification', () {
    test('petit téléphone (320 dp)', () {
      final CinevaMetrics value = metrics(width: 320, height: 568);
      expect(value.isTiny, isTrue);
      expect(value.isPhone, isTrue);
      expect(value.isTablet, isFalse);
      expect(value.isDesktop, isFalse);
      expect(value.gutter, 16);
    });

    test('téléphone standard (390 dp)', () {
      final CinevaMetrics value = metrics(width: 390, height: 844);
      expect(value.isTiny, isFalse);
      expect(value.isPhone, isTrue);
      expect(value.gutter, CinevaSpacing.gutter);
      expect(value.gridColumns, 3);
    });

    test('tablette et desktop', () {
      expect(metrics(width: 820, height: 1180).isTablet, isTrue);
      expect(metrics(width: 820, height: 1180).gridColumns, 5);
      expect(metrics(width: 1440, height: 900).isDesktop, isTrue);
      expect(metrics(width: 1440, height: 900).gridColumns, 7);
    });
  });

  group('CinevaMetrics — dimensions dérivées', () {
    test('largeur d’affiche : laisse voir la carte suivante', () {
      final CinevaMetrics phone = metrics(width: 390, height: 844);
      expect(phone.posterWidth, closeTo(122.85, 0.01));
      // Deux affiches + l’espace ne doivent jamais dépasser l’écran.
      expect(phone.posterWidth * 2 + CinevaSpacing.railGap, lessThan(phone.width));
      expect(metrics(width: 320, height: 568).posterWidth, closeTo(108.8, 0.01));
      expect(metrics(width: 820, height: 1180).posterWidth, 176);
      expect(metrics(width: 1440, height: 900).posterWidth, 200);
    });

    test('hauteur du hero bornée et jamais supérieure à 72 % de l’écran', () {
      final CinevaMetrics phone =
          metrics(width: 390, height: 844, topInset: 47, bottomInset: 34);
      expect(phone.heroHeight, closeTo(503.58, 0.01));
      expect(phone.heroHeight, greaterThanOrEqualTo(400));
      expect(phone.heroHeight, lessThanOrEqualTo(620));

      // Écran très court : la borne basse évite un hero illisible.
      final CinevaMetrics tiny =
          metrics(width: 320, height: 568, topInset: 20, bottomInset: 0);
      expect(tiny.heroHeight, 360);
    });

    test('backdrop de fiche contenu : 58 % de l’écran en portrait', () {
      final CinevaMetrics phone = metrics(width: 390, height: 844);
      expect(phone.detailBackdropHeight, closeTo(489.52, 0.01));
      expect(
        metrics(width: 1440, height: 900).detailBackdropHeight,
        closeTo(450, 0.01),
      );
    });

    test('taille du titre du hero bornée pour les textes agrandis', () {
      expect(metrics(width: 320, height: 568).heroTitleSize, closeTo(27.52, 0.01));
      expect(metrics(width: 1440, height: 900).heroTitleSize, 40);
    });

    test('navigation basse : hauteur fixe hors safe area', () {
      expect(metrics(width: 390, height: 844).bottomNavHeight, 62);
      expect(metrics(width: 390, height: 844).brandHeaderHeight, 52);
    });
  });

  group('Palette premium', () {
    test('noir profond dominant et surfaces étagées', () {
      expect(CinevaColors.ink, const Color(0xFF070707));
      expect(CinevaColors.surface, const Color(0xFF0C0C0C));
      expect(CinevaColors.card, const Color(0xFF111111));
      expect(CinevaColors.raised, const Color(0xFF171717));
    });

    test('accent doré, jamais l’ancien violet', () {
      expect(CinevaColors.gold, const Color(0xFFE4C48C));
      expect(CinevaColors.gold, isNot(CinevaColors.accent));
    });
  });

  group('Jetons de design', () {
    test('espacements croissants', () {
      expect(CinevaSpacing.xs, lessThan(CinevaSpacing.sm));
      expect(CinevaSpacing.sm, lessThan(CinevaSpacing.md));
      expect(CinevaSpacing.md, lessThan(CinevaSpacing.lg));
      expect(CinevaSpacing.lg, lessThan(CinevaSpacing.xl));
      expect(CinevaSpacing.xl, lessThan(CinevaSpacing.xxl));
    });

    test('durées d’animation dans la fenêtre 110–420 ms', () {
      expect(CinevaMotion.instant.inMilliseconds, greaterThanOrEqualTo(100));
      expect(CinevaMotion.fast.inMilliseconds, lessThanOrEqualTo(200));
      expect(CinevaMotion.medium.inMilliseconds, lessThanOrEqualTo(300));
      expect(CinevaMotion.page.inMilliseconds, lessThanOrEqualTo(340));
      // Le texte du hero reste dans la fourchette demandée (500–800 ms).
      expect(CinevaMotion.heroText.inMilliseconds, inInclusiveRange(500, 800));
    });

    test('thème premium : fond noir, accent doré, aucune bordure de carte', () {
      final ThemeData theme = CinevaTheme.premiumDark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, CinevaColors.ink);
      expect(theme.colorScheme.primary, CinevaColors.gold);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(theme.sliderTheme.activeTrackColor, CinevaColors.gold);
      expect(theme.dividerColor, CinevaColors.hairline);
    });
  });
}
