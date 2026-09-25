import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../session/session_controller.dart';
import 'api_exception.dart';
import 'json.dart';
import 'paged.dart';

/// The app's only way to call the AgriLink API.
///
/// - adds `Authorization: Bearer <token>` while signed in
/// - on a 401 ends the session, and the router sends the user to login with "Your session has
///   ended"
/// - turns every failure into an [ApiException]
///
/// Feature API classes take it from [apiClientProvider]:
///
/// ```dart
/// final farmsApiProvider = Provider((ref) => FarmsApi(ref.watch(apiClientProvider)));
///
/// class FarmsApi {
///   FarmsApi(this._api);
///   final ApiClient _api;
///
///   Future<Paged<Farm>> mine({int page = 1}) =>
///       _api.getPaged('/api/farms/mine', page: page, item: Farm.fromJson);
///
///   Future<Farm> create(CreateFarm request) =>
///       _api.post('/api/farms', body: request.toJson(), decode: (d) => Farm.fromJson(asJson(d)));
/// }
/// ```
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  /// Pass as `decode` for endpoints whose response body isn't needed (e.g. 204 No Content).
  static void ignoreBody(Object? _) {}

  Future<T> get<T>(
    String path, {
    Map<String, Object?>? query,
    required T Function(Object? data) decode,
    CancelToken? cancelToken,
  }) => _send(
    () => dio.get<Object?>(path, queryParameters: _clean(query), cancelToken: cancelToken),
    decode,
  );

  /// [receiveTimeout] overrides the default wait for the server's answer, for the rare call that
  /// legitimately takes longer (reporting an issue runs the whole analysis before it responds).
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(Object? data) decode,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) => _send(
    () => dio.post<Object?>(
      path,
      data: body,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: receiveTimeout == null ? null : Options(receiveTimeout: receiveTimeout),
    ),
    decode,
  );

  Future<T> put<T>(String path, {Object? body, required T Function(Object? data) decode}) =>
      _send(() => dio.put<Object?>(path, data: body), decode);

  Future<T> delete<T>(String path, {Object? body, required T Function(Object? data) decode}) =>
      _send(() => dio.delete<Object?>(path, data: body), decode);

  /// A page of a list endpoint that returns `{ items, page, pageSize, totalCount, totalPages }`.
  Future<Paged<T>> getPaged<T>(
    String path, {
    required T Function(Json item) item,
    int page = 1,
    int pageSize = AppConfig.defaultPageSize,
    Map<String, Object?>? query,
    CancelToken? cancelToken,
  }) => get(
    path,
    query: {...?query, 'page': page, 'pageSize': pageSize},
    decode: (data) => Paged.fromJson(asJson(data), item),
    cancelToken: cancelToken,
  );

  Future<T> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? data) decode,
  ) async {
    final Response<Object?> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
    try {
      return decode(response.data);
    } on FormatException catch (error) {
      throw ApiException(
        ApiErrorKind.unknown,
        statusCode: response.statusCode,
        data: error.message,
      );
    } on TypeError catch (error) {
      throw ApiException(
        ApiErrorKind.unknown,
        statusCode: response.statusCode,
        data: error.toString(),
      );
    }
  }

  static Map<String, Object?>? _clean(Map<String, Object?>? query) =>
      query == null ? null : ({...query}..removeWhere((_, value) => value == null));
}

/// Builds the configured Dio. [readToken] and [onUnauthorized] connect it to the session; a
/// test passes its own and an `HttpClientAdapter` that fakes the server.
Dio createDio({
  required String baseUrl,
  required String? Function() readToken,
  required void Function(String? token) onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = readToken();
        if (token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $token';
          options.extra[_tokenExtra] = token;
        }
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          onUnauthorized(error.requestOptions.extra[_tokenExtra] as String?);
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}

const _tokenExtra = 'agrilink.token';

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = createDio(
    baseUrl: AppConfig.apiBaseUrl,
    readToken: () => ref.read(sessionControllerProvider).token,
    onUnauthorized: (token) =>
        ref.read(sessionControllerProvider.notifier).handleUnauthorized(token),
  );
  ref.onDispose(dio.close);
  return ApiClient(dio);
});
