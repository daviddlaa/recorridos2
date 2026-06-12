import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'map_data_usage_service.dart';

/// Tile provider con caché para guardar los tiles y reutilizarlos offline
class CachingTileProvider extends NetworkTileProvider {
  static String? _cachePath;
  static bool _initialized = false;

  CachingTileProvider() : super(httpClient: _CachingHttpClient());

  static Future<String> getCachePath() async {
    if (_initialized) return _cachePath ?? '';
    try {
      final directory = await getApplicationDocumentsDirectory();
      _cachePath = '${directory.path}/map_tiles';
      final cacheDir = Directory(_cachePath!);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('Error inicializando cache de tiles: $e');
    }
    return _cachePath ?? '';
  }
}

class _CachingHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Parsear la URL para obtener x, y, z
    final uri = request.url;
    final pathSegments = uri.pathSegments;

    int? z, x, y;
    if (pathSegments.length >= 3) {
      z = int.tryParse(pathSegments[0]);
      x = int.tryParse(pathSegments[1]);
      final yStr = pathSegments[2].replaceAll('.png', '');
      y = int.tryParse(yStr);
    }

    // Si tenemos coordenadas, verificar caché
    if (z != null && x != null && y != null) {
      final basePath = await CachingTileProvider.getCachePath();
      final filePath = '$basePath/$z/$x/$y.png';
      final file = File(filePath);

      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          // Devolver desde caché
          return http.StreamedResponse(
            Stream.value(bytes),
            200,
            contentLength: bytes.length,
            request: request,
          );
        } catch (e) {
          debugPrint('Error leyendo tile del cache: $e');
        }
      }
    }

    // Descargar si no está en caché
    final response = await _inner.send(request);

    if (response.statusCode == 200 && z != null && x != null && y != null) {
      final chunks = <List<int>>[];
      await for (final chunk in response.stream) {
        chunks.add(chunk);
      }
      final totalBytes = chunks.expand((b) => b).toList();

      // Guardar en caché
      try {
        final basePath = await CachingTileProvider.getCachePath();
        final tilePath = '$basePath/$z/$x/$y.png';
        final tileFile = File(tilePath);
        await tileFile.parent.create(recursive: true);
        await tileFile.writeAsBytes(totalBytes);
      } catch (e) {
        debugPrint('Error guardando tile en cache: $e');
      }

      // Contar bytes descargados
      MapDataUsageService.instance.agregarBytes(totalBytes.length);

      return http.StreamedResponse(
        Stream.value(Uint8List.fromList(totalBytes)),
        response.statusCode,
        contentLength: totalBytes.length,
        request: request,
      );
    }

    return response;
  }

  @override
  void close() {
    _inner.close();
  }
}
