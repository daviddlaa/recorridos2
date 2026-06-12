import 'dart:convert';

import '../models/punto_gps.dart';
import '../models/recorrido.dart';
import '../models/usuario.dart';
import 'db_service.dart';

class SyncImportResult {
  final int usuariosCreados;
  final int recorridosAgregados;
  final int puntosAgregados;
  final int duplicadosIgnorados;

  SyncImportResult({
    required this.usuariosCreados,
    required this.recorridosAgregados,
    required this.puntosAgregados,
    required this.duplicadosIgnorados,
  });

  Map<String, dynamic> toMap() {
    return {
      'usuarios_creados': usuariosCreados,
      'recorridos_agregados': recorridosAgregados,
      'puntos_agregados': puntosAgregados,
      'duplicados_ignorados': duplicadosIgnorados,
    };
  }

  factory SyncImportResult.empty() {
    return SyncImportResult(
      usuariosCreados: 0,
      recorridosAgregados: 0,
      puntosAgregados: 0,
      duplicadosIgnorados: 0,
    );
  }
}

class SyncService {
  final DbService _dbService = DbService();

  Future<String> exportarJson() async {
    await _dbService.asegurarSyncIds();

    final usuarios = await _dbService.getAllUsuarios();
    final recorridos = await _dbService.getAllRecorridos();
    final recorridosJson = <Map<String, dynamic>>[];

    for (final recorrido in recorridos) {
      if (recorrido.id == null) continue;
      final puntos = await _dbService.getPuntosByRecorridoId(recorrido.id!);
      recorridosJson.add({
        'recorrido': recorrido.toMap(),
        'puntos': puntos.map((p) => p.toMap()).toList(),
      });
    }

    return jsonEncode({
      'version': 1,
      'exportado_en': DateTime.now().toIso8601String(),
      'usuarios': usuarios.map((u) => u.toMap()).toList(),
      'recorridos': recorridosJson,
    });
  }

  Future<SyncImportResult> importarJson(String rawJson) async {
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    final usuarios = (data['usuarios'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final recorridos = (data['recorridos'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    var usuariosCreados = 0;
    var recorridosAgregados = 0;
    var puntosAgregados = 0;
    var duplicadosIgnorados = 0;

    for (final usuarioMap in usuarios) {
      final usuario = Usuario.fromMap(usuarioMap);
      final existePorId = await _dbService.getUsuarioById(usuario.id);
      if (existePorId != null) {
        duplicadosIgnorados++;
        continue;
      }

      await _dbService.insertUsuario(usuario);
      usuariosCreados++;
    }

    for (final item in recorridos) {
      final recorridoMap = item['recorrido'] as Map<String, dynamic>;
      final puntosMaps = (item['puntos'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final recorridoEntrante = Recorrido.fromMap(recorridoMap);

      if (recorridoEntrante.syncId == null ||
          recorridoEntrante.syncId!.isEmpty) {
        duplicadosIgnorados++;
        continue;
      }

      var recorridoLocal = await _dbService.getRecorridoBySyncId(
        recorridoEntrante.syncId!,
      );

      int recorridoLocalId;
      if (recorridoLocal == null) {
        recorridoLocalId = await _dbService.insertRecorrido(
          Recorrido(
            syncId: recorridoEntrante.syncId,
            userId: recorridoEntrante.userId,
            fecha: recorridoEntrante.fecha,
            nombre: recorridoEntrante.nombre,
          ),
        );
        recorridosAgregados++;
      } else {
        if (recorridoLocal.id == null) {
          duplicadosIgnorados++;
          continue;
        }
        recorridoLocalId = recorridoLocal.id!;
        duplicadosIgnorados++;
      }

      for (final puntoMap in puntosMaps) {
        final puntoEntrante = PuntoGps.fromMap(puntoMap);
        if (puntoEntrante.syncId == null || puntoEntrante.syncId!.isEmpty) {
          duplicadosIgnorados++;
          continue;
        }

        final existe = await _dbService.existePuntoBySyncId(
          puntoEntrante.syncId!,
        );
        if (existe) {
          duplicadosIgnorados++;
          continue;
        }

        await _dbService.insertPunto(
          PuntoGps(
            syncId: puntoEntrante.syncId,
            recorridoId: recorridoLocalId,
            latitud: puntoEntrante.latitud,
            longitud: puntoEntrante.longitud,
            fechaHora: puntoEntrante.fechaHora,
          ),
        );
        puntosAgregados++;
      }
    }

    return SyncImportResult(
      usuariosCreados: usuariosCreados,
      recorridosAgregados: recorridosAgregados,
      puntosAgregados: puntosAgregados,
      duplicadosIgnorados: duplicadosIgnorados,
    );
  }
}
