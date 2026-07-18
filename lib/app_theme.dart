import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppSize {
  static const touch = 48.0;
  static const logo = 80.0;
  static const contentMax = 720.0;
  static const artworkMax = 480.0;
  static const detailMinWidth = 136.0;
  static const artworkCacheWidth = 800;
  static const transportIcon = 36.0;
  static const connectionIcon = 12.0;
}

abstract final class AppRadius {
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 28.0;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFE9B44C),
          brightness: brightness,
        ).copyWith(
          surface: dark ? const Color(0xFF15171A) : const Color(0xFFFFF9EE),
          surfaceContainer: dark
              ? const Color(0xFF202328)
              : const Color(0xFFF4EAD7),
          surfaceContainerHigh: dark
              ? const Color(0xFF292D33)
              : const Color(0xFFEADCC3),
        );

    final base = ThemeData(
      brightness: brightness,
      colorScheme: colors,
      fontFamily: 'sans-serif',
      scaffoldBackgroundColor: colors.surface,
      useMaterial3: true,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
          fontFamily: 'sans-serif-condensed',
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppSize.touch),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
          borderSide: BorderSide.none,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontFamily: 'sans-serif-condensed',
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}
