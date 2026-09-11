import 'package:flutter/material.dart';

abstract final class CinevaColors {
  static const background = Color(0xFF050505);
  static const surface = Color(0xFF101014);
  static const surfaceRaised = Color(0xFF16161B);
  static const surfaceOverlay = Color(0xFF1B1B22);
  static const border = Color(0x26FFFFFF);
  static const textPrimary = Color(0xFFF5F2EC);
  static const textMuted = Color(0xB3F5F2EC);
  static const accent = Color(0xFF7C4DFF);
  static const accentSoft = Color(0xFF9D84FF);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFFF5C7A);

  static const lightBackground = Color(0xFFF7F6F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFF0EEF8);
  static const lightTextPrimary = Color(0xFF111114);
  static const lightTextMuted = Color(0xCC111114);
  static const lightBorder = Color(0x12000000);
}

abstract final class CinevaRadii {
  static const small = 18.0;
  static const medium = 24.0;
  static const large = 32.0;
}

abstract final class CinevaSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class CinevaTheme {
  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData light() => _build(brightness: Brightness.light);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? CinevaColors.surface : CinevaColors.lightSurface;
    final background = isDark ? CinevaColors.background : CinevaColors.lightBackground;
    final text = isDark ? CinevaColors.textPrimary : CinevaColors.lightTextPrimary;
    final textMuted = isDark ? CinevaColors.textMuted : CinevaColors.lightTextMuted;
    final border = isDark ? CinevaColors.border : CinevaColors.lightBorder;
    final snack = isDark ? CinevaColors.surfaceOverlay : CinevaColors.lightSurfaceRaised;

    final colorScheme = ColorScheme.fromSeed(
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

    final base = ThemeData(
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
          borderRadius: BorderRadius.circular(CinevaRadii.medium),
          side: BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
