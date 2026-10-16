import '../../core/constants/notification_types.dart';

/// Where tapping a notification should take the reader, or null when it is
/// informational only.
///
/// Deliberately role-aware and conservative: it never returns a route the
/// reader cannot open. A driver cannot fetch a ride they have not accepted, so
/// a `ride_request` alert only leads home (where the request list lives), and
/// anything without a ride id can only be marked read.
String? notificationDestination({
  required String? type,
  required Map<String, dynamic>? metadata,
  required bool isDriver,
}) {
  final rideId = metadata?['rideId']?.toString();
  final hasRide = rideId != null && rideId.isNotEmpty;

  switch (type) {
    case NotificationTypes.rideRequest:
      // The driver cannot open a ride they have not accepted yet.
      return '/home';
    case NotificationTypes.rideStarted:
      return hasRide ? '/ride/$rideId/tracking' : null;
    case NotificationTypes.rideCompleted:
      // Both sides land on the receipt, which is where the fare, the
      // transaction and the rating live. The passenger is offered a rating
      // there (or sees the one they gave) instead of being taken straight to a
      // rating form they may already have filled in.
      return hasRide ? '/ride/$rideId/details' : null;
    case NotificationTypes.paymentSent:
      return hasRide ? '/ride/$rideId/details' : null;
    case NotificationTypes.paymentReceived:
      return hasRide ? '/ride/$rideId/details' : null;
    case NotificationTypes.message:
      return hasRide ? '/ride/$rideId/tracking?chat=1' : null;
    default:
      // Announcements, safety notices and cancellations are read-only.
      return null;
  }
}
