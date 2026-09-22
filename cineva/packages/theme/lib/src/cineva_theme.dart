import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cineva_metrics.dart';
import 'cineva_palette.dart';
import 'cineva_typography.dart';

/// Thèmes Material Cineva.
///
/// * [premiumDark] : thème de l'application abonné (mobile, TV, desktop) —
///   noir profond, surfaces étagées, or/champagne en accent rare.
/// * [dark] / [light] : thèmes historiques (console d'administration et
///   préférence « Thème » de l'utilisateur).
abstract final class CinevaTheme {
  /// Overlay système adapté aux fonds très sombres (barre d'état claire,
  /// barre de navigation transparente pour laisser vivre les safe areas).
  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  );

  /// Thème principal de l'app Cineva.
  static ThemeData premiumDark() => _premium(brightness: Brightness.dark);

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData light() => _build(brightness: Brightness.light);

  // ------------------------------------------------------------------ premium
  static ThemeData _premium({required Brightness brightness}) {
    const ColorScheme scheme = ColorScheme.dark(
      primary: CinevaColors.gold,
      onPrimary: CinevaColors.textOnLight,
      primaryContainer: Color(0xFF3A3123),
      onPrimaryContainer: CinevaColors.goldBright,
      secondary: CinevaColors.textHigh,
      onSecondary: CinevaColors.textOnLight,
      secondaryContainer: CinevaColors.raised,
      onSecondaryContainer: CinevaColors.textHigh,
      tertiary: CinevaColors.goldDeep,
      onTertiary: CinevaColors.textOnLight,
      surface: CinevaColors.surface,
      onSurface: CinevaColors.textHigh,
      surfaceContainerLowest: CinevaColors.ink,
      surfaceContainerLow: CinevaColors.surface,
      surfaceContainer: CinevaColors.card,
      surfaceContainerHigh: CinevaColors.raised,
      surfaceContainerHighest: CinevaColors.overlay,
      onSurfaceVariant: CinevaColors.textSoft,
      outline: CinevaColors.hairline,
      outlineVariant: CinevaColors.hairline,
      error: CinevaColors.danger,
      onError: Colors.white,
      inverseSurface: CinevaColors.textHigh,
      onInverseSurface: CinevaColors.ink,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: CinevaColors.ink,
      canvasColor: CinevaColors.ink,
      dividerColor: CinevaColors.hairline,
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final TextTheme text = CinevaTypography.applyTo(base.textTheme);

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: CinevaTypography.applyTo(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: CinevaColors.textHigh,
        centerTitle: false,
        titleTextStyle: CinevaTypography.sectionTitle,
        systemOverlayStyle: overlay,
      ),
      cardTheme: CardTheme(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: CinevaColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.card)),
      ),
      dividerTheme: const DividerThemeData(
        color: CinevaColors.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: CinevaColors.textSoft,
        textColor: CinevaColors.textHigh,
        minVerticalPadding: 10,
        contentPadding: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CinevaColors.field,
        hintStyle: text.bodyMedium?.copyWith(color: CinevaColors.textFaint),
        labelStyle: text.bodyMedium?.copyWith(color: CinevaColors.textFaint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          borderSide: const BorderSide(color: CinevaColors.goldGlow, width: 1.2),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: CinevaColors.gold,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: CinevaColors.textHigh,
        overlayColor: Color(0x1FE4C48C),
        trackHeight: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? CinevaColors.textOnLight
              : CinevaColors.textSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? CinevaColors.gold
              : CinevaColors.raised,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? CinevaColors.gold
              : CinevaColors.textFaint,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? CinevaColors.gold
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll<Color>(CinevaColors.textOnLight),
        side: const BorderSide(color: CinevaColors.textFaint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.hair)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CinevaColors.gold,
        linearTrackColor: CinevaColors.raised,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CinevaColors.modal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: Color(0x33FFFFFF),
        shape: RoundedRectangleBorder(borderRadius: CinevaRadii.sheetBorder),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: CinevaColors.modal,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.large)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CinevaColors.overlay,
        contentTextStyle: text.bodyMedium?.copyWith(color: CinevaColors.textHigh),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.medium)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: CinevaColors.overlay,
          borderRadius: BorderRadius.circular(CinevaRadii.small),
        ),
        textStyle: text.bodySmall?.copyWith(color: CinevaColors.textHigh),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CinevaColors.textHigh,
          splashFactory: NoSplash.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: text.labelLarge?.copyWith(color: CinevaColors.textHigh),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CinevaColors.textHigh,
          side: const BorderSide(color: CinevaColors.hairlineStrong),
          splashFactory: NoSplash.splashFactory,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.chip)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CinevaColors.textHigh,
          foregroundColor: CinevaColors.textOnLight,
          splashFactory: NoSplash.splashFactory,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.chip)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CinevaColors.textHigh,
          foregroundColor: CinevaColors.textOnLight,
          elevation: 0,
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CinevaColors.card,
        selectedColor: CinevaColors.textHigh,
        side: BorderSide.none,
        labelStyle: text.labelMedium?.copyWith(color: CinevaColors.textSoft),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: CinevaColors.textOnLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CinevaRadii.chip)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CinevaColors.surface.withOpacity(0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelTextStyle: const WidgetStatePropertyAll<TextStyle>(CinevaTypography.navLabel),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(Color(0x33FFFFFF)),
        thickness: const WidgetStatePropertyAll<double>(3),
        radius: const Radius.circular(999),
      ),
      iconTheme: const IconThemeData(color: CinevaColors.textHigh, size: 22),
      primaryIconTheme: const IconThemeData(color: CinevaColors.textHigh),
    );
  }

  // ----------------------------------------------------------------- héritage
  static ThemeData _build({required Brightness brightness}) {
    final bool isDark = brightness == Brightness.dark;
    final Color surface = isDark ? CinevaColors.surface : CinevaColors.lightSurface;
    final Color background = isDark ? CinevaColors.background : CinevaColors.lightBackground;
    final Color text = isDark ? CinevaColors.textPrimary : CinevaColors.lightTextPrimary;
    final Color textMuted = isDark ? CinevaColors.textMuted : CinevaColors.lightTextMuted;
    final Color border = isDark ? CinevaColors.border : CinevaColors.lightBorder;
    final Color snack = isDark ? CinevaColors.surfaceOverlay : CinevaColors.lightSurfaceRaised;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: CinevaColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: CinevaColors.accent,
      onPrimary: Colors.white,
      secondary: CinevaColors.accentSoft,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: text,
      error: CinevaColors.danger,
      onError: Colors.white,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      splashFactory: NoSplash.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
      ),
      cardTheme: CardTheme(
        margin: EdgeInsets.zero,
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.legacyMedium),
          side: BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.legacyMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.legacyMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CinevaRadii.legacyMedium),
          borderSide: const BorderSide(color: CinevaColors.accentSoft),
        ),
        hintStyle: TextStyle(color: textMuted.withOpacity(0.8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withOpacity(isDark ? 0.94 : 0.98),
        indicatorColor: CinevaColors.accent.withOpacity(0.16),
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(
            color: text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: snack,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(color: text),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: text),
        displayMedium: base.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: text),
        displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: text),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: text),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: text),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: text),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: text),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: text),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: text),
      ),
    );
  }
}


