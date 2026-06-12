import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData getThemeData(AppColors colors, bool isDarkMode) {
    if (isDarkMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: colors.primary,
          secondary: colors.secondary,
          surface: colors.surface,
          error: colors.error,
        ),
        scaffoldBackgroundColor: colors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: colors.primary),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          prefixIconColor: colors.primary,
        ),
        drawerTheme: DrawerThemeData(backgroundColor: colors.surface),
        listTileTheme: ListTileThemeData(iconColor: colors.primary),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(color: colors.surface),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: colors.primary,
          secondary: colors.secondary,
          surface: colors.surface,
          error: colors.error,
        ),
        scaffoldBackgroundColor: colors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: colors.primary),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          prefixIconColor: colors.primary,
          labelStyle: TextStyle(color: colors.primary),
        ),
        drawerTheme: DrawerThemeData(backgroundColor: colors.surface),
        listTileTheme: ListTileThemeData(iconColor: colors.primary),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(color: colors.surface),
      );
    }
  }
}
