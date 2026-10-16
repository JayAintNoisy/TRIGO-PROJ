import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';

class RidesRepository {
  final Dio _dio = dioClient;

  /// Ride statuses that mean a trip is still in flight. Anything not in this
  /// set (completed, cancelled) is terminal and belongs in history only.
  static const Set<String> activeStatuses = {
    'requested',
    'accepted',
    'driver_arriving',
    'in_progress',
  };

  static bool isActiveStatus(String? status) =>
      status != null && activeStatuses.contains(status);

  /// Ride statuses that mean a driver is actually committed to the trip.
  ///
  /// Deliberately excludes `requested`: that state means no driver has
  /// accepted yet, so it is an open request rather than any driver's ride.
  /// A driver resuming after a restart must never be dropped into one.
  static const Set<String> driverAssignedStatuses = {
    'accepted',
    'driver_arriving',
    'in_progress',
  };

  static bool isDriverAssignedStatus(String? status) =>
      status != null && driverAssignedStatuses.contains(status);

  /// Human-readable label for an in-flight ride, so the customer sees which
  /// stage they are actually at rather than a generic "Active".
  static String activeStatusLabel(String? status) {
    switch (status) {
      case 'requested':
        return 'Finding a driver';
      case 'accepted':
        return 'Driver on the way';
      case 'driver_arriving':
        return 'Driver arriving';
      case 'in_progress':
        return 'Trip in progress';
      default:
        return 'Active';
    }
  }

  /// Newest completed trip first.
  ///
  /// The list endpoint orders by `created_at`, which is when the passenger
  /// booked — not when the trip finished. For an earnings or history list that
  /// is the wrong key: a ride booked earlier but completed later would sort
  /// below an older trip, so the order is re-derived here from the completion
  /// time (falling back to creation for anything without one).
  static List<dynamic> sortByCompletedDesc(List<dynamic> rides) {
    final sorted = [...rides];
    sorted.sort((a, b) => _completionTime(b).compareTo(_completionTime(a)));
    return sorted;
  }

  static DateTime _completionTime(dynamic ride) {
    if (ride is! Map) return DateTime.fromMillisecondsSinceEpoch(0);
    final completed = DateTime.tryParse(ride['completedAt']?.toString() ?? '');
    if (completed != null) return completed;
    return DateTime.tryParse(ride['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

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

  /// The customer's current in-flight ride, or null when none exists.
  ///
  /// The list endpoint returns the user's rides newest-first, so the first
  /// non-terminal entry is the one to resume. Used both to pin the active
  /// card in History and to restore the ride after an app restart.
  Future<dynamic> getActiveRide() async {
    final rides = await getRides();
    for (final ride in rides) {
      if (ride is Map && isActiveStatus(ride['status']?.toString())) {
        return ride;
      }
    }
    return null;
  }

  /// The ride a driver is currently committed to, or null when they are idle.
  ///
  /// `/rides` is scoped to the caller, so for a driver this returns the rides
  /// assigned to them. Only rides they have actually accepted count — an open
  /// `requested` ride belongs to the customer, not to any driver.
  Future<dynamic> getDriverAssignedRide() async {
    final rides = await getRides();
    for (final ride in rides) {
      if (ride is Map && isDriverAssignedStatus(ride['status']?.toString())) {
        return ride;
      }
    }
    return null;
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

  /// Changes a rating already given. Only allowed inside the rating edit
  /// window; the backend rejects a late change with a readable message.
  Future<dynamic> updateRating(String id, int rating, {String? comment}) async {
    final response = await _dio.patch(
      '${ApiEndpoints.rides}/$id/rating',
      data: {'rating': rating, if (comment != null) 'comment': comment},
    );
    return response.data['data'];
  }

  /// The method a completed ride was settled with, falling back to the method
  /// the passenger chose. Null when neither is known.
  static String? settledPaymentMethod(Map<dynamic, dynamic> ride) {
    final settled = ride['settledPaymentMethod']?.toString();
    if (settled != null && settled.isNotEmpty) return settled;
    final chosen = ride['paymentMethod']?.toString();
    if (chosen != null && chosen.isNotEmpty) return chosen;
    return null;
  }

  /// The passenger's rating of the driver, or null when unrated.
  static int? ratingOf(Map<dynamic, dynamic> ride) {
    final value = ride['rating'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
  ///
  /// Passing [rideId] also records the point against the trip, which is what
  /// lets the passenger's poll of the ride payload pick up a fresh driver
  /// position mid-trip.
  Future<void> broadcastLocation({
    required double lat,
    required double lng,
    double? accuracy,
    String? rideId,
  }) async {
    await _dio.post(ApiEndpoints.trackingLocation, data: {
      'lat': lat,
      'lng': lng,
      if (accuracy != null) 'accuracy': accuracy,
      if (rideId != null) 'rideId': rideId,
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
