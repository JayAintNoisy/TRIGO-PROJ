import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/notification_types.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';

/// A notification worth interrupting the user for, shown as a foreground
/// banner. Popped from the state once displayed.
class NotificationBanner {
  const NotificationBanner({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.metadata,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? metadata;

  IconData get icon => notificationVisualFor(type).icon;
}

class NotificationCenterState {
  const NotificationCenterState({
    this.unreadCount = 0,
    this.latest = const [],
    this.banner,
  });

  final int unreadCount;

  /// Most recent page of notifications, kept so the badge, the banner and the
  /// "mark this ride's messages read" action all work from one fetch.
  final List<dynamic> latest;

  final NotificationBanner? banner;

  NotificationCenterState copyWith({
    int? unreadCount,
    List<dynamic>? latest,
    NotificationBanner? banner,
    bool clearBanner = false,
  }) {
    return NotificationCenterState(
      unreadCount: unreadCount ?? this.unreadCount,
      latest: latest ?? this.latest,
      banner: clearBanner ? null : (banner ?? this.banner),
    );
  }
}

/// Keeps the unread badge and the foreground banner in sync for the session.
///
/// Polling is deliberately split: a cheap count every [pollInterval] that
/// triggers a single list fetch whenever the count grows, which is what makes
/// "new notification" detection possible without fetching the list constantly.
class NotificationCenterNotifier extends StateNotifier<NotificationCenterState> {
  NotificationCenterNotifier(this._repository, {bool enabled = true})
      : super(const NotificationCenterState()) {
    if (enabled) start();
  }

  static const Duration pollInterval = Duration(seconds: 20);

  final NotificationsRepository _repository;
  Timer? _timer;
  final Set<String> _knownIds = {};

  /// The first successful poll seeds the known ids without firing banners for
  /// notifications that were already there before the app opened.
  bool _seeded = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Polls the count and, only when it grew, pulls the list to find what is new.
  Future<void> refresh() async {
    try {
      final count = await _repository.getUnreadCount();

      if (_seeded && count <= state.unreadCount) {
        if (count != state.unreadCount) {
          state = state.copyWith(unreadCount: count);
        }
        return;
      }

      final list = await _repository.getNotifications();
      final unread = list
          .whereType<Map>()
          .where((item) => item['isRead'] == false)
          .toList();

      NotificationBanner? banner;
      if (_seeded) {
        for (final item in unread) {
          final id = item['id']?.toString() ?? '';
          if (id.isEmpty || _knownIds.contains(id)) continue;
          banner ??= _bannerFor(Map<String, dynamic>.from(item));
        }
      }

      _knownIds
        ..clear()
        ..addAll(unread.map((item) => item['id']?.toString() ?? ''));
      _seeded = true;

      state = state.copyWith(
        unreadCount: count,
        latest: list,
        banner: banner,
        clearBanner: banner == null,
      );
    } catch (_) {
      // A failed poll must never disturb the screen; retried on the next tick.
    }
  }

  /// Reloads the latest page, used after the reader has changed read state.
  Future<void> reloadList() async {
    try {
      final list = await _repository.getNotifications();
      final unread = list
          .whereType<Map>()
          .where((item) => item['isRead'] == false)
          .length;
      state = state.copyWith(latest: list, unreadCount: unread);
    } catch (_) {
      // Ignored; the next poll corrects the badge.
    }
  }

  /// Marks every unread `message` notification for [rideId] as read, so the
  /// badge clears as soon as the passenger or driver opens the thread.
  Future<void> markRideMessagesRead(String rideId) async {
    if (state.latest.isEmpty) await reloadList();

    final targets = state.latest.whereType<Map>().where((item) {
      final metadata = item['metadata'];
      return item['isRead'] == false &&
          item['type'] == NotificationTypes.message &&
          metadata is Map &&
          metadata['rideId']?.toString() == rideId;
    }).toList();

    for (final item in targets) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      try {
        await _repository.markAsRead(id);
        item['isRead'] = true;
      } catch (_) {
        // Leave it unread; the reader can still clear it from the list.
      }
    }

    if (targets.isNotEmpty) {
      final remaining = state.latest
          .whereType<Map>()
          .where((item) => item['isRead'] == false)
          .length;
      state = state.copyWith(unreadCount: remaining);
    }
  }

  void consumeBanner() {
    if (state.banner != null) state = state.copyWith(clearBanner: true);
  }

  NotificationBanner _bannerFor(Map<String, dynamic> item) {
    final metadata = item['metadata'];
    return NotificationBanner(
      id: item['id']?.toString() ?? '',
      type: item['type']?.toString() ?? '',
      title: item['title']?.toString() ?? 'Notification',
      body: item['body']?.toString() ?? '',
      metadata: metadata is Map ? Map<String, dynamic>.from(metadata) : null,
    );
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository());

final notificationCenterProvider =
    StateNotifierProvider<NotificationCenterNotifier, NotificationCenterState>(
  (ref) {
    final repository = ref.watch(notificationsRepositoryProvider);
    // Rebuilt only when the session starts or ends, so the badge and the
    // known-id set survive profile refreshes.
    final isAuthenticated = ref.watch(
      authProvider.select((state) => state.isAuthenticated),
    );
    return NotificationCenterNotifier(repository, enabled: isAuthenticated);
  },
);
