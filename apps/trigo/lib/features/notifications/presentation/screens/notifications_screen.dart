import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../ride_booking/data/rides_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _repository = NotificationsRepository();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _error;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _repository.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(dynamic notification) async {
    if (notification['isRead'] == true) return;
    try {
      await _repository.markAsRead(notification['id'].toString());
      if (mounted) setState(() => notification['isRead'] = true);
    } catch (_) {}
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'ride_completed':
        return Icons.check_circle_outline;
      case 'announcement':
        return Icons.campaign;
      case 'safety':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorFor(String? type) {
    switch (type) {
      case 'ride_completed':
        return const Color(0xFF059669);
      case 'announcement':
        return const Color(0xFF3B82F6);
      case 'safety':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey.shade500;
    }
  }

  String _timeAgo(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildNotificationItem({
    required dynamic notification,
  }) {
    final title = notification['title']?.toString() ?? '';
    final message = notification['body']?.toString() ?? '';
    final type = notification['type']?.toString();
    final isUnread = notification['isRead'] == false;
    final iconColor = _colorFor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(type), color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _timeAgo(notification['createdAt']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((n) => n['isRead'] == false).length;
    final visible = _showUnreadOnly
        ? _notifications.where((n) => n['isRead'] == false).toList()
        : _notifications;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const AppTopBar(title: 'Notifications'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style:
                              const TextStyle(color: Color(0xFFDC2626))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _load();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      setState(() => _showUnreadOnly = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !_showUnreadOnly
                                        ? const Color(0xFF3B82F6)
                                        : Colors.grey.shade100,
                                    foregroundColor: !_showUnreadOnly
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  child: Text('All (${_notifications.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => setState(
                                      () => _showUnreadOnly = true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _showUnreadOnly
                                        ? const Color(0xFF3B82F6)
                                        : Colors.grey.shade100,
                                    foregroundColor: _showUnreadOnly
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  child: Text('Unread ($unreadCount)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_off_outlined,
                                      size: 64,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text('No notifications yet',
                                      style: TextStyle(
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final item =
                                      GestureDetector(
                                    onTap: () => _markAsRead(visible[index]),
                                    child: _buildNotificationItem(
                                        notification: visible[index]),
                                  );
                                  return item;
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}
