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

  Future<List<dynamic>> getRides({String? status}) async {
    final response = await _dio.get(
      ApiEndpoints.rides,
      queryParameters: {if (status != null) 'status': status},
    );
    return (response.data['data'] as List?) ?? [];
  }

  // Open ride requests in the driver's municipality
  Future<List<dynamic>> getAvailableRides() async {
    try {
      final response = await _dio.get(ApiEndpoints.availableRides);
      return (response.data['data'] as List?) ?? [];
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  Future<List<dynamic>> getMunicipalities() async {
    final response = await _dio.get(ApiEndpoints.municipalities);
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

  /// Publishes the driver's GPS fix so /drivers/online and the admin live
  /// tracking map reflect their position.
  Future<void> broadcastLocation({
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    await _dio.post(ApiEndpoints.trackingLocation, data: {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
    });
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
    final response = await _dio.get(ApiEndpoints.driversOnline);
    return (response.data['data'] as List?) ?? [];
  }
}

class NotificationsRepository {
  final Dio _dio = dioClient;

  Future<List<dynamic>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    return (response.data['data'] as List?) ?? [];
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }
}
