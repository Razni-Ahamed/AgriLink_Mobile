import 'dart:convert';
import 'dart:typed_data';

import 'package:agrilink_mobile/core/api/api_client.dart';
import 'package:dio/dio.dart';

/// A pretend AgriLink API for tests. Nothing goes over the network.
///
/// ```dart
/// final api = FakeApi()
///   ..on('POST', '/api/auth/login', (r) => FakeResponse(200, {'token': 't', 'role': 'Farmer'}));
/// ```
///
/// Unhandled requests fail with a 404 so a missing stub is obvious.
class FakeApi implements HttpClientAdapter {
  final List<_Route> _routes = [];

  /// Every request the app made, in order.
  final List<RecordedRequest> requests = [];

  /// Registers a handler. [path] matches the request path exactly (without the query).
  void on(
    String method,
    String path,
    FakeResponse Function(RecordedRequest request) handler,
  ) {
    _routes.insert(0, _Route(method, path, handler));
  }

  /// A handler that throws a connection error, like being offline.
  void offline(String method, String path) {
    on(method, path, (_) => throw const _Offline());
  }

  RecordedRequest? lastTo(String method, String path) {
    for (final request in requests.reversed) {
      if (request.method == method && request.path == path) {
        return request;
      }
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = RecordedRequest(
      method: options.method,
      path: options.uri.path,
      query: options.uri.queryParameters,
      headers: options.headers,
      body: options.data,
    );
    requests.add(request);
    for (final route in _routes) {
      if (route.method == options.method && route.path == options.uri.path) {
        final FakeResponse response;
        try {
          response = route.handler(request);
        } on _Offline {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return ResponseBody.fromString(
          response.body == null ? '' : jsonEncode(response.body),
          response.status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({
        'message': 'No fake for ${options.method} ${options.uri.path}',
      }),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeResponse {
  const FakeResponse(this.status, [this.body]);
  final int status;
  final Object? body;
}

class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, dynamic> headers;
  final Object? body;

  Map<String, dynamic> get json => body! as Map<String, dynamic>;
}

class _Route {
  _Route(this.method, this.path, this.handler);
  final String method;
  final String path;
  final FakeResponse Function(RecordedRequest request) handler;
}

class _Offline implements Exception {
  const _Offline();
}

/// An [ApiClient] backed by [api]. Pass [readToken] / [onUnauthorized] to connect a session.
ApiClient fakeApiClient(
  FakeApi api, {
  String? Function()? readToken,
  void Function(String? token)? onUnauthorized,
}) {
  return ApiClient(
    createDio(
      baseUrl: 'https://api.test',
      readToken: readToken ?? () => null,
      onUnauthorized: onUnauthorized ?? (_) {},
      adapter: api,
    ),
  );
}
