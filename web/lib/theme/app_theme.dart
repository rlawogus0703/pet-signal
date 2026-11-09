import 'package:flutter/material.dart';

/// 펫 시그널 디자인 시스템 (코랄 + 딥 네이비)
class AppColors {
  static const coral = Color(0xFFFF6B4A);
  static const coralDark = Color(0xFFE5532F);
  static const coralSoft = Color(0xFFFFEDE7);
  static const navy = Color(0xFF16233F);
  static const navySoft = Color(0xFF2A3A5E);
  static const bg = Color(0xFFFAF7F4);
  static const surface = Colors.white;
  static const line = Color(0xFFEDE7E2);
  static const text = Color(0xFF1C2333);
  static const subtext = Color(0xFF6B7280);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  /// 점수 구간별 색
  static Color score(double v) {
    if (v >= 0.75) return coral;
    if (v >= 0.55) return const Color(0xFFF59E0B);
    if (v >= 0.35) return const Color(0xFF64748B);
    return const Color(0xFFB0B7C3);
  }
}

class Gap {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x0F16233F), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const hover = [
    BoxShadow(color: Color(0x2216233F), blurRadius: 28, offset: Offset(0, 12)),
  ];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.coral,
    primary: AppColors.coral,
    onPrimary: Colors.white,
    secondary: AppColors.navy,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    brightness: Brightness.light,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: AppColors.bg,
  );
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text).copyWith(
          headlineLarge: const TextStyle(fontWeight: FontWeight.w800, fontSize: 34, letterSpacing: -0.8),
          headlineMedium: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.5),
          headlineSmall: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21, letterSpacing: -0.3),
          titleLarge: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.2),
          titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
          bodyMedium: const TextStyle(fontSize: 14.5, height: 1.5),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(
          fontFamily: 'Pretendard', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFCFBFA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: AppColors.coral, width: 1.6)),
      labelStyle: const TextStyle(color: AppColors.subtext),
      hintStyle: const TextStyle(color: Color(0xFFA0A6B1)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: const BorderSide(color: AppColors.line, width: 1.4),
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.coralDark,
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w500),
      selectedColor: AppColors.coralSoft,
      backgroundColor: Colors.white,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    }),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.coralSoft,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Pretendard', fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
    ),
  );
}
