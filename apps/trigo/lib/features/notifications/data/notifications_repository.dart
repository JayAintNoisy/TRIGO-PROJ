import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

/// The signed-in user's notifications, regardless of role.
class NotificationsRepository {
  final Dio _dio = dioClient;

  Future<List<dynamic>> getNotifications() async {
    final response = await _dio.get(ApiEndpoints.notifications);
    return (response.data['data'] as List?) ?? [];
  }

  /// Badge count only, so polling it stays cheap.
  Future<int> getUnreadCount() async {
    final response = await _dio.get(ApiEndpoints.notificationUnreadCount);
    final data = response.data['data'];
    if (data is Map) return (data['count'] as num?)?.toInt() ?? 0;
    return 0;
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('${ApiEndpoints.notifications}/$id/read');
  }
}
