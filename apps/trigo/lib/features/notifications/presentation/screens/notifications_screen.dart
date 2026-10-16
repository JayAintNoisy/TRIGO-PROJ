import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/notification_types.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';
import '../../notification_destination.dart';
import '../providers/notification_center.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({
    super.key,
    this.notificationLoader,
    this.markReadOverride,
  });

  /// Overrides how notifications are fetched. Defaults to the real repository;
  /// tests inject a stub so no network or .env is required.
  @visibleForTesting
  final Future<List<dynamic>> Function()? notificationLoader;

  /// Overrides marking a notification read, for the same reason.
  @visibleForTesting
  final Future<void> Function(String id)? markReadOverride;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late final NotificationsRepository _repository =
      NotificationsRepository();

  Future<List<dynamic>> _fetch() =>
      widget.notificationLoader?.call() ?? _repository.getNotifications();

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
      final list = await _fetch();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
          _error = null;
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
      final id = notification['id'].toString();
      final override = widget.markReadOverride;
      if (override != null) {
        await override(id);
      } else {
        await _repository.markAsRead(id);
      }
      if (mounted) setState(() => notification['isRead'] = true);
    } catch (_) {
      // Leave it unread so the reader can try again.
    }
  }

  /// Marks the tapped notification read and, where the kind has a destination
  /// the reader may open, navigates there.
  Future<void> _openNotification(dynamic notification) async {
    await _markAsRead(notification);

    final isDriver = ref.read(authProvider).activeMode == AppUserMode.driver;
    final metadata = notification['metadata'];
    final destination = notificationDestination(
      type: notification['type']?.toString(),
      metadata: metadata is Map ? Map<String, dynamic>.from(metadata) : null,
      isDriver: isDriver,
    );
    if (destination == null || !mounted) return;

    context.push(destination);
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

  Widget _buildNotificationItem({required dynamic notification}) {
    final title = notification['title']?.toString() ?? '';
    final message = notification['body']?.toString() ?? '';
    final type = notification['type']?.toString();
    final isUnread = notification['isRead'] == false;
    final visual = notificationVisualFor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? visual.color.withValues(alpha: 0.25)
              : Colors.grey.shade100,
        ),
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
              color: visual.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(visual.icon, color: visual.color, size: 20),
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
                              onRefresh: () async {
                                await _load();
                                // The badge is derived from the same rows.
                                await ref
                                    .read(notificationCenterProvider.notifier)
                                    .reloadList();
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final item = GestureDetector(
                                    onTap: () =>
                                        _openNotification(visible[index]),
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
