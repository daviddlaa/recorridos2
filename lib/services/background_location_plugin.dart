import 'dart:async';
import 'package:flutter/services.dart';

class BackgroundLocationPlugin {
  static const MethodChannel _channel = MethodChannel(
    'io.flutter.plugins/georuta_background',
  );

  /// Iniciar servicio en segundo plano con duración opcional
  /// [duracionMinutos] - Duración en minutos (0 = sin límite/manual)
  static Future<bool> startForegroundService({int duracionMinutos = 0}) async {
    try {
      final result = await _channel.invokeMethod('startForegroundService', {
        'duracion': duracionMinutos,
      });
      return result == true;
      // ignore: unused_catch_clause
    } on PlatformException catch (e) {
      return false;
    }
  }

  static Future<bool> stopForegroundService() async {
    try {
      final result = await _channel.invokeMethod('stopForegroundService');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Actualizar el tiempo restante en la notificación
  /// [segundosRestantes] - Segundos restantes para finalizar
  static Future<bool> actualizarTiempo(int segundosRestantes) async {
    try {
      final result = await _channel.invokeMethod('actualizarTiempo', {
        'segundos': segundosRestantes,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  static Stream<Map<String, dynamic>> get locationStream {
    return EventChannel(
      'io.flutter.plugins/location_events',
    ).receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      return <String, dynamic>{};
    });
  }
}
