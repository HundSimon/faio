import 'package:flutter/material.dart';

/// Centralises theming for coherent styling across the app.
abstract final class AppTheme {
  static const _seed = Color(0xFF4A7BB6);

  static ThemeData get light => _base(
    brightness: Brightness.light,
  ).copyWith(scaffoldBackgroundColor: Colors.grey.shade50);

  static ThemeData get dark => _base(
    brightness: Brightness.dark,
  ).copyWith(scaffoldBackgroundColor: const Color(0xFF121212));

  static ThemeData _base({required Brightness brightness}) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      navigationBarTheme: const NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
