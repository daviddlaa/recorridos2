import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = LoggerService();
    final colores = ThemeService.currentTheme;
    final isDark = ThemeService.isDarkMode;
    final theme = AppTheme.getThemeData(colores, isDark);

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logs', style: TextStyle(fontSize: 16)),
          actions: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: logger.getAllLogsAsText()),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Logs copiados')));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear',
              onPressed: () {
                logger.clear();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Logs limpiados')));
              },
            ),
          ],
        ),
        body: StreamBuilder<void>(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logger.logs.length,
              itemBuilder: (context, index) {
                final entry = logger.logs[index];
                Color textColor = isDark ? Colors.white : Colors.black87;

                switch (entry.level) {
                  case LoggerService.debug:
                    textColor = Colors.grey;
                    break;
                  case LoggerService.info:
                    textColor = isDark ? Colors.white : Colors.black87;
                    break;
                  case LoggerService.warning:
                    textColor = Colors.orange;
                    break;
                  case LoggerService.error:
                    textColor = Colors.redAccent;
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: SelectableText(
                    entry.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: textColor,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
