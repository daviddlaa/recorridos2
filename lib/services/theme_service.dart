import '../theme/app_colors.dart';

/// Servicio estático para el tema actual
class ThemeService {
  static AppColors _currentTheme = AppThemeOptions.defaultTheme;

  static AppColors get currentTheme => _currentTheme;

  static bool get isDarkMode => _currentTheme.name == 'Dark Moderno';

  /// Configurar el tema actual
  static void setTheme(AppColors theme) {
    _currentTheme = theme;
  }

  /// Configurar por índice (0-3)
  static void setThemeByIndex(int index) {
    _currentTheme = AppThemeOptions.getThemeByIndex(index);
  }
}
