import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'map_data_usage_service.dart';

class CountingTileProvider extends NetworkTileProvider {
  CountingTileProvider()
    : super(httpClient: _CountingHttpClient(http.Client()));
}

class _CountingHttpClient extends http.BaseClient {
  final http.Client _inner;

  _CountingHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);

    final countedStream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          MapDataUsageService.instance.agregarBytes(chunk.length);
          sink.add(chunk);
        },
      ),
    );

    return http.StreamedResponse(
      countedStream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _inner.close();
  }
}
