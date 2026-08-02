import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';
import 'auth_interceptor.dart';

Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(AuthInterceptor(dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
}

Dio? _dioClient;

Dio get dioClient {
  _dioClient ??= createDioClient();
  return _dioClient!;
}

final tokenProvider = _TokenProvider();

class _TokenProvider {
  String? _cachedToken;
  bool _loaded = false;

  Future<String?> getToken() async {
    if (_loaded) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('trigo_token');
    _loaded = true;
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trigo_token', token);
  }

  Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trigo_refresh_token', token);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('trigo_refresh_token');
  }

  Future<void> clearTokens() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trigo_token');
    await prefs.remove('trigo_refresh_token');
  }

  void clearToken() {
    _cachedToken = null;
  }
}
