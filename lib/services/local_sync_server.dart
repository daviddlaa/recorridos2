import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'sync_service.dart';

class LocalSyncServer {
  final SyncService _syncService = SyncService();
  HttpServer? _server;
  String? clave;
  String? ip;
  int? puerto;
  void Function(SyncImportResult resultado)? onImportResult;

  bool get activo => _server != null;

  Future<void> iniciar() async {
    if (_server != null) return;

    clave = _generarClave();
    ip = await obtenerIpLocal();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    puerto = _server!.port;
    _server!.listen(_manejarRequest);
  }

  Future<void> detener() async {
    await _server?.close(force: true);
    _server = null;
    clave = null;
    ip = null;
    puerto = null;
  }

  Future<void> _manejarRequest(HttpRequest request) async {
    try {
      if (request.method != 'POST' || request.uri.path != '/sync') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final claveRecibida = request.headers.value('x-sync-key');
      if (claveRecibida != clave) {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.write(jsonEncode({'error': 'Clave incorrecta'}));
        await request.response.close();
        return;
      }

      final body = await utf8.decoder.bind(request).join();
      final resultado = await _syncService.importarJson(body);
      onImportResult?.call(resultado);

      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'ok': true,
        'resultado': resultado.toMap(),
      }));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  static String _generarClave() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  static Future<String?> obtenerIpLocal() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final ip = address.address;
        if (!ip.startsWith('127.')) return ip;
      }
    }

    return null;
  }
}

class LocalSyncClient {
  final SyncService _syncService = SyncService();

  Future<Map<String, dynamic>> enviarDatos({
    required String ip,
    required int puerto,
    required String clave,
  }) async {
    final json = await _syncService.exportarJson();
    final client = HttpClient();

    try {
      final request = await client.post(ip, puerto, '/sync');
      request.headers.contentType = ContentType.json;
      request.headers.set('x-sync-key', clave);
      request.write(json);

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      final data = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode != HttpStatus.ok) {
        throw Exception(data['error'] ?? 'Error de sincronizacion');
      }

      return data;
    } finally {
      client.close(force: true);
    }
  }
}
