import 'package:flutter/material.dart';

class AppTheme {
  // ── 核心配色 ──
  static const Color primary = Color(0xFF0D7C66);
  static const Color primaryLight = Color(0xFF15A085);
  static const Color primaryDark = Color(0xFF095E4C);
  static const Color accent = Color(0xFFF5A623);
  static const Color accentLight = Color(0xFFFFC857);

  static const Color surface = Color(0xFFF8FAF9);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE8EDEB);

  static const Color textPrimary = Color(0xFF1A2E2A);
  static const Color textSecondary = Color(0xFF7A8F89);
  static const Color textHint = Color(0xFFB0C1BA);

  static const Color success = Color(0xFF41B883);
  static const Color error = Color(0xFFE8616A);
  static const Color warning = Color(0xFFF5A623);

  static const Color gradientStart = Color(0xFF0D7C66);
  static const Color gradientEnd = Color(0xFF15A085);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0D7C66).withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0D7C66).withOpacity(0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static double get radiusSm => 8;
  static double get radiusMd => 12;
  static double get radiusLg => 16;
  static double get radiusXl => 24;

  static double get spaceXs => 4;
  static double get spaceSm => 8;
  static double get spaceMd => 16;
  static double get spaceLg => 24;
  static double get spaceXl => 32;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: surface,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        actionsIconTheme: IconThemeData(color: textSecondary),
        iconTheme: IconThemeData(color: textSecondary),
      ),

      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shadowColor: const Color(0xFF0D7C66).withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: divider, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF2F5F4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF2F5F4),
        selectedColor: primary.withOpacity(0.12),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      dividerTheme:
          const DividerThemeData(color: divider, thickness: 1, space: 0),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }
}
