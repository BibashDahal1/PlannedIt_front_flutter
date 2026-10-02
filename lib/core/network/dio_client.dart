import 'package:dio/dio.dart';
import '../config/env.dart';
import '../storage/secure_token_storage.dart';
import 'api_endpoints.dart';

/// Every request gets the access token attached automatically.
/// On a 401, it tries exactly one silent refresh-and-retry before
/// giving up and clearing tokens (which effectively logs the user out).
class DioClient {
  DioClient(this._tokenStorage)
    : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isPublicAuthRoute =
              options.path == ApiEndpoints.signupRequest ||
              options.path == ApiEndpoints.signupVerify ||
              options.path == ApiEndpoints.loginRequest ||
              options.path == ApiEndpoints.loginVerify ||
              options.path == ApiEndpoints.tokenRefresh;
          if (!isPublicAuthRoute) {
            final token = await _tokenStorage.accessToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (isUnauthorized && !alreadyRetried) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              final newToken = await _tokenStorage.accessToken;
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                return handler.next(error);
              }
            } else {
              // Refresh token is dead too — clear everything so the next
              // profile fetch/restoreSession call correctly reports "logged out".
              await _tokenStorage.clear();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final SecureTokenStorage _tokenStorage;

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) return false;

    try {
      // A separate, interceptor-free Dio instance -- reusing `dio` here
      // would re-trigger this same onError handler and risk a loop.
      final plainDio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
      final response = await plainDio.post(
        ApiEndpoints.tokenRefresh,
        data: {'refresh': refreshToken},
      );
      await _tokenStorage.saveTokens(
        access: response.data['access'] as String,
        refresh: response.data['refresh'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
