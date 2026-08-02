import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import 'api_client.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenProvider.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final path = err.requestOptions.path;
    if (path.contains('/auth/')) {
      return handler.next(err);
    }

    final refreshToken = await tokenProvider.getRefreshToken();
    if (refreshToken == null) {
      return handler.next(err);
    }

    try {
      final response = await Dio(BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
      )).post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data;
      if (data['success'] == true) {
        final newAccessToken = data['data']['accessToken'] as String;
        await tokenProvider.setToken(newAccessToken);

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        final retry = await dio.fetch(err.requestOptions);
        return handler.resolve(retry);
      }
    } catch (_) {
      await tokenProvider.clearTokens();
    }

    return handler.next(err);
  }
}
