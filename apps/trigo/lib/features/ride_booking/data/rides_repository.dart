import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';

class RidesRepository {
  final Dio _dio = dioClient;

  Future<dynamic> requestRide({
    required String municipalityId,
    required double pickupLat,
    required double pickupLng,
    String? pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    String? dropoffAddress,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.rides, data: {
        'municipalityId': municipalityId,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        if (pickupAddress != null) 'pickupAddress': pickupAddress,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        if (dropoffAddress != null) 'dropoffAddress': dropoffAddress,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  Future<List<dynamic>> getRides() async {
    final response = await _dio.get(ApiEndpoints.rides);
    return (response.data['data'] as List?) ?? [];
  }

  Future<dynamic> getRideById(String id) async {
    final response = await _dio.get('${ApiEndpoints.rides}/$id');
    return response.data['data'];
  }

  Future<dynamic> acceptRide(String id) async {
    final response = await _dio.post('${ApiEndpoints.rides}/$id/accept');
    return response.data['data'];
  }

  Future<dynamic> arrive(String id) async {
    final response = await _dio.post('${ApiEndpoints.rides}/$id/arrive');
    return response.data['data'];
  }

  Future<dynamic> startRide(String id) async {
    final response = await _dio.post('${ApiEndpoints.rides}/$id/start');
    return response.data['data'];
  }

  Future<dynamic> completeRide(String id) async {
    final response = await _dio.post('${ApiEndpoints.rides}/$id/complete');
    return response.data['data'];
  }

  Future<dynamic> cancelRide(String id, {String? reason}) async {
    final response = await _dio.post(
      '${ApiEndpoints.rides}/$id/cancel',
      data: {if (reason != null) 'reason': reason},
    );
    return response.data['data'];
  }

  Future<dynamic> rateRide(String id, int rating, {String? comment}) async {
    final response = await _dio.post(
      '${ApiEndpoints.rides}/$id/rate',
      data: {'rating': rating, if (comment != null) 'comment': comment},
    );
    return response.data['data'];
  }
}

class DriversRepository {
  final Dio _dio = dioClient;

  Future<dynamic> getMe() async {
    final response = await _dio.get(ApiEndpoints.driverMe);
    return response.data['data'];
  }

  Future<dynamic> toggleOnlineStatus(bool isOnline) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.driverOnlineStatus,
        data: {'isOnline': isOnline},
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  Future<dynamic> apply({
    required String municipalityId,
    required String licenseNumber,
    required String tricyclePlateNumber,
    String? tricycleModel,
    required List<Map<String, String>> documents,
  }) async {
    try {
      final response = await _dio.post(ApiEndpoints.applyDriver, data: {
        'municipalityId': municipalityId,
        'licenseNumber': licenseNumber,
        'tricyclePlateNumber': tricyclePlateNumber,
        if (tricycleModel != null) 'tricycleModel': tricycleModel,
        'documents': documents,
      });
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  Future<List<dynamic>> getDrivers() async {
    final response = await _dio.get('/drivers');
    return (response.data['data'] as List?) ?? [];
  }
}
