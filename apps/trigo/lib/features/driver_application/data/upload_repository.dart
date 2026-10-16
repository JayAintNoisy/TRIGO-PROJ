import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/error_parser.dart';

/// Uploads files to the backend and returns the stored relative URL.
///
/// This is the app-wide upload entry point: driver verification documents and
/// payment QR codes both go through it.
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

  /// Uploads in-memory bytes, used for images the app produced itself (for
  /// example a cropped payment QR code) so no temporary file is needed.
  Future<String> uploadBytes(
    Uint8List bytes, {
    required String filename,
    required String folder,
    required DioMediaType contentType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'folder': folder,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: contentType,
        ),
      });
      final response = await _dio.post(ApiEndpoints.uploads, data: formData);
      return response.data['data']['url'] as String;
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }
}
