import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';
import 'auth_response.dart';

class AuthRepository {
  final Dio _dio = dioClient;

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      if (data['success'] != true) {
      throw Exception(extractApiError(data));
    }

    final authResponse = AuthResponse.fromJson(
        data['data'] as Map<String, dynamic>,
      );

      await tokenProvider.setToken(authResponse.accessToken);
      await tokenProvider.setRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      throw Exception(_extractError(errorData));
    }
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    bool asDriver = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'phone': phone,
          'asDriver': asDriver,
        },
      );

      final data = response.data;
      if (data['success'] != true) {
      throw Exception(extractApiError(data));
    }

    final authResponse = AuthResponse.fromJson(
        data['data'] as Map<String, dynamic>,
      );

      await tokenProvider.setToken(authResponse.accessToken);
      await tokenProvider.setRefreshToken(authResponse.refreshToken);

      return authResponse;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      throw Exception(_extractError(errorData));
    }
  }

  Future<UserData> getCurrentUser() async {
    try {
      final response = await _dio.get(ApiEndpoints.me);
      final data = response.data;
      if (data['success'] != true) {
        throw Exception(_extractError(data));
      }
      return UserData.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final errorData = e.response?.data;
      throw Exception(_extractError(errorData));
    }
  }

  Future<void> logout() async {
    await tokenProvider.clearTokens();
  }

  String _extractError(dynamic data) {
    return extractApiError(data);
  }
}
