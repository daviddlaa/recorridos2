import 'package:flutter/material.dart';

/// Definición de los 4 temas de color disponibles
class AppColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color error;
  final String name;
  final String icon;

  const AppColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.error,
    required this.name,
    required this.icon,
  });
}

/// Los 4 temas disponibles
class AppThemeOptions {
  static const List<AppColors> themes = [
    AppColors(
      primary: Color(0xFF2E7D32), // Verde bosque
      secondary: Color(0xFFD84315), // Naranja terracotta
      background: Color(0xFFF5F5F5),
      surface: Colors.white,
      error: Color(0xFFB00020),
      name: 'Verde Naturaleza',
      icon: '🌲',
    ),
    AppColors(
      primary: Color(0xFF1565C0), // Azul profundo
      secondary: Color(0xFF00BCD4), // Cyan brilhante
      background: Color(0xFFF5F5F5),
      surface: Colors.white,
      error: Color(0xFFB00020),
      name: 'Azul Océano',
      icon: '🌊',
    ),
    AppColors(
      primary: Color(0xFF00E676), // Verde brilhante (para dark)
      secondary: Color(0xFF69F0AE),
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFCF6679),
      name: 'Dark Moderno',
      icon: '🌙',
    ),
    AppColors(
      primary: Color(0xFF795548), // Marrón terracotta
      secondary: Color(0xFFF9A825), // Amarillo mostaza
      background: Color(0xFFF5F5F5),
      surface: Colors.white,
      error: Color(0xFFB00020),
      name: 'Terracotta',
      icon: '🏜️',
    ),
  ];

  static AppColors get defaultTheme => themes[0];
  static AppColors getThemeByIndex(int index) {
    if (index >= 0 && index < themes.length) {
      return themes[index];
    }
    return defaultTheme;
  }
}
