import 'package:flutter/material.dart';
import '../models/app_settings.dart';

extension MealTypography on ThemeData {
  TextStyle? get representativeMenuStyle => textTheme.bodyLarge?.copyWith(
    color: brightness == Brightness.dark
        ? const Color(0xfff2a5a5)
        : const Color(0xffb94a4a),
    fontWeight: FontWeight.w500,
    height: 1.6,
  );
}

ThemeData mealTheme(Backdrop preset, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xff242830) : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff345f9e),
    brightness: brightness,
  ).copyWith(surface: surface);
  final bg = Color(dark ? preset.dark : preset.light);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      height: 72,
    ),
  );
}
