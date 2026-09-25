import 'package:dio/dio.dart';

enum ApiErrorKind {
  /// No response: offline, DNS failure, connection refused.
  network,

  /// The server didn't answer in time (it may be waking up).
  timeout,

  /// The request was cancelled by the app.
  cancelled,

  /// 400: a business rule (`{ message }`) or validation (`{ errors }`) failure.
  badRequest,

  /// 401: not signed in or the session was rejected. The API client signs out on its own.
  unauthorized,

  /// 403.
  forbidden,

  /// 404.
  notFound,

  /// 409: e.g. the email or username is already taken.
  conflict,

  /// 5xx.
  server,

  /// Any other status, or a response the app couldn't read.
  unknown,
}

/// Every failed API call throws this, whatever went wrong. Show it to the user with
/// `parseApiError` (form screens) or `ErrorView` (whole screens).
class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.data});

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(ApiErrorKind.timeout);
      case DioExceptionType.cancel:
        return const ApiException(ApiErrorKind.cancelled);
      case DioExceptionType.connectionError:
        return const ApiException(ApiErrorKind.network);
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final response = error.response;
        if (response == null) {
          return const ApiException(ApiErrorKind.network);
        }
        return ApiException.fromStatus(response.statusCode, response.data);
    }
  }

  factory ApiException.fromStatus(int? statusCode, [Object? data]) {
    final kind = switch (statusCode) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      final int code when code >= 500 => ApiErrorKind.server,
      _ => ApiErrorKind.unknown,
    };
    return ApiException(kind, statusCode: statusCode, data: data);
  }

  final ApiErrorKind kind;
  final int? statusCode;

  /// The decoded response body, if there was one.
  final Object? data;

  /// True when the request never got an answer: show "Can't reach the server" with a retry.
  bool get isConnectivity => kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  /// The server's own `{ message }`, if it sent one. It is in English.
  String? get serverMessage {
    final body = data;
    if (body is Map && body['message'] is String) {
      final message = (body['message'] as String).trim();
      return message.isEmpty ? null : message;
    }
    return null;
  }

  /// A string field of the error body, such as `reason` on a rejected login.
  String? bodyField(String name) {
    final body = data;
    return body is Map && body[name] is String ? body[name] as String : null;
  }

  @override
  String toString() => 'ApiException($kind, status: $statusCode, message: $serverMessage)';
}
