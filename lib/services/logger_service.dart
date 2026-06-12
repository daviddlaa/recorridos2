import 'dart:collection';

/// Simple in-memory log storage for debugging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final List<LogEntry> _logs = [];
  static const int maxLogs = 500;

  // Log levels
  static const String debug = 'DEBUG';
  static const String info = 'INFO';
  static const String warning = 'WARNING';
  static const String error = 'ERROR';

  void log(String message, {String level = info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
    );
    _logs.add(entry);

    // Keep only last maxLogs entries
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
  }

  void d(String message) => log(message, level: debug);
  void i(String message) => log(message, level: info);
  void w(String message) => log(message, level: warning);
  void e(String message) => log(message, level: error);

  List<LogEntry> get logs => UnmodifiableListView(_logs);

  void clear() {
    _logs.clear();
  }

  String getAllLogsAsText() {
    final buffer = StringBuffer();
    for (final entry in _logs) {
      buffer.writeln(entry.toString());
    }
    return buffer.toString();
  }
}

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  @override
  String toString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    return '[$time] $level: $message';
  }
}
