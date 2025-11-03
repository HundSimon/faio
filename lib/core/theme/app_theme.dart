import 'package:flutter/material.dart';

/// Centralises theming for coherent styling across the app.
abstract final class AppTheme {
  static ThemeData get light {
    const seed = Color(0xFF4A7BB6);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: Colors.grey.shade50,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
