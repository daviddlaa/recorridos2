import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'services/theme_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final coloresActuales = ThemeService.currentTheme;
    final isDarkMode = ThemeService.isDarkMode;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GeoRuta',
      theme: AppTheme.getThemeData(coloresActuales, isDarkMode),
      initialRoute: '/login',
      routes: {'/login': (context) => const LoginScreen()},
    );
  }
}
