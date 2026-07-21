import 'package:flutter/material.dart';

class AppTheme {
  // ── 核心配色 ──
  static const Color primary = Color(0xFF0B5C8E);
  static const Color primaryLight = Color(0xFF2E9FD8);
  static const Color primaryDark = Color(0xFF063A63);
  static const Color navy = Color(0xFF071B33);
  static const Color navyLight = Color(0xFF0F2C4D);
  static const Color accent = Color(0xFF19B7D8);
  static const Color accentLight = Color(0xFF7DE3F4);

  static const Color surface = Color(0xFFF2F8FC);
  static const Color darkSurface = Color(0xFF061426);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFD9E9F2);
  static const Color darkDivider = Color(0xFF24435F);
  static const Color glassFill = Color(0xCCFFFFFF);
  static const Color glassFillStrong = Color(0xE6FFFFFF);
  static const Color glassStroke = Color(0x99FFFFFF);
  static const Color darkGlassFill = Color(0x99112A45);
  static const Color darkGlassFillStrong = Color(0xCC0B213A);
  static const Color darkGlassStroke = Color(0x335FAFDB);

  static const Color textPrimary = Color(0xFF0D2438);
  static const Color textSecondary = Color(0xFF667F91);
  static const Color textHint = Color(0xFF9FB5C4);
  static const Color darkTextPrimary = Color(0xFFE9F6FF);
  static const Color darkTextSecondary = Color(0xFFA7C1D6);
  static const Color darkTextHint = Color(0xFF6F8CA3);

  static const Color success = Color(0xFF41B883);
  static const Color error = Color(0xFFE8616A);
  static const Color warning = Color(0xFFF5A623);

  static const Color gradientStart = Color(0xFF063A63);
  static const Color gradientEnd = Color(0xFF0B5C8E);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF063A63).withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF063A63).withOpacity(0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
  static List<BoxShadow> get glassShadow => [
        BoxShadow(
          color: const Color(0xFF063A63).withOpacity(0.08),
          blurRadius: 30,
          spreadRadius: -10,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.65),
          blurRadius: 1,
          offset: const Offset(0, 1),
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withOpacity(0.72),
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        actionsIconTheme: const IconThemeData(color: textSecondary),
        iconTheme: const IconThemeData(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: glassFill,
        elevation: 0,
        shadowColor: const Color(0xFF063A63).withOpacity(0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.white.withOpacity(0.72), width: 1),
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
            borderRadius: BorderRadius.circular(radiusLg),
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
        fillColor: Colors.white.withOpacity(0.72),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.86)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.86)),
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.72),
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEAF4FA),
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        onPrimary: navy,
        secondary: accentLight,
        onSecondary: navy,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: darkSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: navy.withOpacity(0.78),
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        actionsIconTheme: const IconThemeData(color: darkTextSecondary),
        iconTheme: const IconThemeData(color: darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: darkGlassFill,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: darkGlassStroke, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: navy,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: navyLight.withOpacity(0.74),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkGlassStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkGlassStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextHint),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navy.withOpacity(0.78),
        selectedItemColor: primaryLight,
        unselectedItemColor: darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: navyLight,
        selectedColor: primaryLight.withOpacity(0.20),
        labelStyle: const TextStyle(color: darkTextPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: darkDivider, thickness: 1, space: 0),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }
}
