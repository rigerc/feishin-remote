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
  static ThemeData light({String? accent}) => _build(Brightness.light, accent);

  static ThemeData dark({String? accent}) => _build(Brightness.dark, accent);

  static Color? _parseAccent(String? value) {
    if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
  }

  static ThemeData _build(Brightness brightness, String? accent) {
    final dark = brightness == Brightness.dark;
    final colors =
        ColorScheme.fromSeed(
          seedColor: _parseAccent(accent) ?? const Color(0xFFE9B44C),
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
