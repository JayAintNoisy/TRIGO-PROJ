import 'package:flutter/material.dart';

/// Notification kinds written by the backend.
///
/// Mirrors `trigo-backend/src/shared/constants/notification-types.ts`; the
/// strings are the wire contract stored in `notifications.type`.
class NotificationTypes {
  const NotificationTypes._();

  static const String rideRequest = 'ride_request';
  static const String rideStarted = 'ride_started';
  static const String rideCompleted = 'ride_completed';
  static const String rideCancelled = 'ride_cancelled';
  static const String paymentSent = 'payment_sent';
  static const String paymentReceived = 'payment_received';
  static const String message = 'message';
  static const String announcement = 'announcement';
  static const String safety = 'safety';
}

/// How one notification kind is presented in the list and the heads-up banner.
@immutable
class NotificationVisual {
  const NotificationVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Icon and accent colour per kind, with a neutral fallback for unknown types
/// (the backend may add kinds before the app is updated).
NotificationVisual notificationVisualFor(String? type) {
  switch (type) {
    case NotificationTypes.rideRequest:
      return const NotificationVisual(
        icon: Icons.electric_rickshaw,
        color: Color(0xFF2563EB),
      );
    case NotificationTypes.rideStarted:
      return const NotificationVisual(
        icon: Icons.navigation_rounded,
        color: Color(0xFF3B82F6),
      );
    case NotificationTypes.rideCompleted:
      return const NotificationVisual(
        icon: Icons.check_circle_outline,
        color: Color(0xFF059669),
      );
    case NotificationTypes.rideCancelled:
      return const NotificationVisual(
        icon: Icons.cancel_outlined,
        color: Color(0xFF64748B),
      );
    case NotificationTypes.paymentSent:
      return const NotificationVisual(
        icon: Icons.arrow_upward_rounded,
        color: Color(0xFF0D9488),
      );
    case NotificationTypes.paymentReceived:
      return const NotificationVisual(
        icon: Icons.arrow_downward_rounded,
        color: Color(0xFF0D9488),
      );
    case NotificationTypes.message:
      return const NotificationVisual(
        icon: Icons.chat_bubble_outline,
        color: Color(0xFF4F46E5),
      );
    case NotificationTypes.announcement:
      return const NotificationVisual(
        icon: Icons.campaign_outlined,
        color: Color(0xFF3B82F6),
      );
    case NotificationTypes.safety:
      return const NotificationVisual(
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFEF4444),
      );
    default:
      return NotificationVisual(
        icon: Icons.notifications_none,
        color: Colors.grey.shade500,
      );
  }
}
