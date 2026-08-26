import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFF07080A);
  static const Color backgroundSecondary = Color(0xFF0D0F14);
  static const Color surface = Color(0xFF131720);
  static const Color surfaceElevated = Color(0xFF1A1F2C);

  static const Color glassSurface = Color(0xCC131720);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color glassBorderGold = Color(0x40D4AF37);
  static const Color goldHover = Color(0x1FD4AF37);

  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryGoldBright = Color(0xFFF5D76E);
  static const Color primaryGoldDark = Color(0xFFA67C00);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0x1F10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0x1FF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0x1FEF4444);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [primaryGoldBright, primaryGold, primaryGoldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1B202C), Color(0xFF11141B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryGold,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGold,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundSecondary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: AppColors.glassBorder,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
