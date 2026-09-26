import 'package:flutter/material.dart';

// سیستم Paper & Glass — ۴ تم: کاغذی / سپیا / خاکستری / مشکی AMOLED
class PaperGlassTheme {
  static const gold = Color(0xFFC9A86A);
  static const inkBg = Color(0xFF14121F);

  static ThemeData paper() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.light,
      ).copyWith(surface: const Color(0xFFF5EFE2)),
      scaffoldBackgroundColor: const Color(0xFFF5EFE2),
    );
  }

  static ThemeData sepia() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.light,
      ).copyWith(surface: const Color(0xFFE8D5B5)),
      scaffoldBackgroundColor: const Color(0xFFE8D5B5),
    );
  }

  static ThemeData greyNight() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ).copyWith(surface: const Color(0xFF2A2A35)),
      scaffoldBackgroundColor: const Color(0xFF1C1B28),
    );
  }

  static ThemeData amoled() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ).copyWith(surface: Colors.black, primary: gold),
      scaffoldBackgroundColor: Colors.black,
    );
  }
}
