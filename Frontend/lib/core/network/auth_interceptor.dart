import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, {required this.onUnauthorized});

  final SecureStorageService _storage;
  final Future<void> Function() onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // A 401 from login means "wrong password", not "session expired".
    final path = err.requestOptions.path;
    final isAuthCall = path == ApiEndpoints.login || path == ApiEndpoints.register;
    if (err.response?.statusCode == 401 && !isAuthCall) {
      await onUnauthorized();
    }
    handler.next(err);
  }
}
