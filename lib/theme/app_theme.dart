import 'package:flutter/material.dart';

/// Design tokens. Semua warna & style teks di-pusatin di sini
/// biar konsisten dan gampang di-tweak.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0B0B0D);
  static const surface = Color(0xFF17171C);
  static const surfaceElevated = Color(0xFF1F1F26);
  static const divider = Color(0xFF232329);

  // Aksen emas/amber — nyambung sama tema xianxia/wuxia (api, pedang, dll)
  static const accent = Color(0xFFE3A657);
  static const accentDim = Color(0xFF9C7A4A);

  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFF9A9AA4);
  static const textTertiary = Color(0xFF6B6B74);
}

class AppText {
  AppText._();

  static const largeTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const navTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const sectionTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static const sectionAction = TextStyle(
    color: AppColors.accent,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const cardSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  static const badge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const heroTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const heroSubtitle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
  );
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: '.SF Pro Text',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.divider,
  );
}
