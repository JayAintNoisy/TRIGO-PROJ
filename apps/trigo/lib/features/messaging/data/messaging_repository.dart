import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_parser.dart';

/// One chat message on a ride.
class RideMessage {
  const RideMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.senderName,
  });

  final String id;
  final String rideId;
  final String senderId;
  final String body;
  final DateTime? createdAt;

  /// Set once the other party has opened the thread.
  final DateTime? readAt;

  final String? senderName;

  factory RideMessage.fromJson(Map<String, dynamic> json) {
    return RideMessage(
      id: json['id']?.toString() ?? '',
      rideId: json['rideId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
      senderName: json['senderName'] as String?,
    );
  }

  /// Parses a message list payload, skipping anything malformed.
  static List<RideMessage> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => RideMessage.fromJson(Map<String, dynamic>.from(item)))
        .where((message) => message.id.isNotEmpty)
        .toList();
  }
}

/// In-app chat between the two participants of a ride.
class MessagingRepository {
  final Dio _dio = dioClient;

  Future<List<RideMessage>> getMessages(String rideId) async {
    final response = await _dio.get(ApiEndpoints.rideMessages(rideId));
    return RideMessage.listFrom(response.data['data']);
  }

  Future<RideMessage> sendMessage(String rideId, String body) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.rideMessages(rideId),
        data: {'body': body},
      );
      return RideMessage.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw Exception(extractApiError(e.response?.data));
    }
  }

  /// Marks everything the other party sent as read.
  Future<void> markRead(String rideId) async {
    await _dio.patch(ApiEndpoints.rideMessagesRead(rideId));
  }
}
