import 'package:flutter/material.dart';

class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0F6C5A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD9F5EA),
    onPrimaryContainer: Color(0xFF062A22),
    secondary: Color(0xFF1A3A5F),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD7E5FF),
    onSecondaryContainer: Color(0xFF081B31),
    tertiary: Color(0xFF8C5E16),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFE7C2),
    onTertiaryContainer: Color(0xFF311D00),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF4F7F2),
    onSurface: Color(0xFF142018),
    surfaceContainerHighest: Color(0xFFDDE6DD),
    onSurfaceVariant: Color(0xFF415046),
    outline: Color(0xFF6D7D72),
    outlineVariant: Color(0xFFBCC9BE),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF28342C),
    onInverseSurface: Color(0xFFECF3EB),
    inversePrimary: Color(0xFF7FD8BD),
    surfaceTint: Color(0xFF0F6C5A),
  );

  static ThemeData get light => _theme(_lightScheme);
  static ThemeData get dark => _theme(_lightScheme);

  static ThemeData _theme(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'SF Pro Display',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: TextStyle(
          fontSize: 42,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          color: scheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 34,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: scheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: scheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: scheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withAlpha(220),
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(180)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(220),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withAlpha(160),
          fontWeight: FontWeight.w500,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withAlpha(60),
        selectionHandleColor: scheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withAlpha(225),
        surfaceTintColor: Colors.transparent,
        height: 76,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
