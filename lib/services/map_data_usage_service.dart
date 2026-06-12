import 'dart:async';

import 'package:flutter/foundation.dart';

import 'db_service.dart';

class MapDataUsageService {
  MapDataUsageService._();

  static final MapDataUsageService instance = MapDataUsageService._();

  final DbService _dbService = DbService();
  final ValueNotifier<int> bytesNotifier = ValueNotifier<int>(0);

  bool _inicializado = false;
  Timer? _guardarTimer;

  Future<void> inicializar() async {
    if (_inicializado) return;
    bytesNotifier.value = await _dbService.getMapDataUsageBytes();
    _inicializado = true;
  }

  void agregarBytes(int bytes) {
    if (bytes <= 0) return;
    bytesNotifier.value += bytes;
    _programarGuardado();
  }

  Future<void> reiniciar() async {
    _guardarTimer?.cancel();
    bytesNotifier.value = 0;
    await _dbService.setMapDataUsageBytes(0);
  }

  String formatearBytes(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb < 1) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }

  void _programarGuardado() {
    _guardarTimer?.cancel();
    _guardarTimer = Timer(const Duration(seconds: 2), () {
      _dbService.setMapDataUsageBytes(bytesNotifier.value);
    });
  }
}
