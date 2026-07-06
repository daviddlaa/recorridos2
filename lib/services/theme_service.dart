import '../theme/app_colors.dart';

/// Servicio estático para el tema actual.
/// Ahora siempre retorna el tema por defecto (Verde Naturaleza).
class ThemeService {
  static AppColors get currentTheme => AppThemeOptions.defaultTheme;

  static bool get isDarkMode => false;
}
