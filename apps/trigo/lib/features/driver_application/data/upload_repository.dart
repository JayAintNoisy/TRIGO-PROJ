import 'dart:io';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/error_parser.dart';

/// Uploads documents to the backend and returns the stored relative URL
class UploadRepository {
  final Dio _dio = dioClient;

  Future<String> uploadDocument(
    File file, {
    String folder = 'driver-documents',
  }) async {
    try {
      final formData = FormData.fromMap({
        'folder': folder,
        'file': await MultipartFile.fromFile(file.path),
      });
      final response = await _dio.post(ApiEndpoints.uploads, data: formData);
      return response.data['data']['url'] as String;
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }
}
