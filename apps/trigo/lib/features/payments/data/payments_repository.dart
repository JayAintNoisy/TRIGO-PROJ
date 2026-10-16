import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';

/// A recorded payment for a finished ride — the "transaction" behind a trip.
class RidePayment {
  const RidePayment({
    required this.id,
    required this.rideId,
    required this.amount,
    required this.method,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String rideId;
  final double amount;

  /// Wire value (`cash`, `gcash`, …); render it through the payment catalog.
  final String method;

  /// `pending`, `completed` or `refunded`.
  final String status;

  final DateTime? createdAt;

  factory RidePayment.fromJson(Map<String, dynamic> json) {
    return RidePayment(
      id: json['id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method']?.toString() ?? 'cash',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

/// Payment records, as opposed to a driver's payment method configuration.
class PaymentsRepository {
  final Dio _dio = dioClient;

  /// The payment recorded for a ride, or null when none exists yet (an
  /// unfinished or cancelled trip has no transaction).
  Future<RidePayment?> getRidePayment(String rideId) async {
    try {
      final response = await _dio.get('${ApiEndpoints.payments}/ride/$rideId');
      final data = response.data['data'];
      if (data is! Map) return null;
      return RidePayment.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(extractApiError(e.response?.data));
    }
  }
}
