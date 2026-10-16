import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/core/constants/notification_types.dart';
import 'package:trigo/features/notifications/notification_destination.dart';

/// Notification presentation rules, mirrored from the backend's type ids.
void main() {
  group('notificationVisualFor', () {
    test('gives every backend type its own icon and colour', () {
      const types = [
        NotificationTypes.rideRequest,
        NotificationTypes.rideStarted,
        NotificationTypes.rideCompleted,
        NotificationTypes.rideCancelled,
        NotificationTypes.paymentSent,
        NotificationTypes.paymentReceived,
        NotificationTypes.message,
        NotificationTypes.announcement,
        NotificationTypes.safety,
      ];

      final icons = types.map((t) => notificationVisualFor(t).icon).toSet();
      expect(icons.length, types.length,
          reason: 'each kind should be visually distinguishable');

      for (final type in types) {
        expect(notificationVisualFor(type).icon, isA<IconData>());
      }
    });

    test('falls back safely for an unknown or missing type', () {
      final unknown = notificationVisualFor('something_new');
      expect(unknown.icon, Icons.notifications_none);
      expect(notificationVisualFor(null).icon, Icons.notifications_none);
    });
  });

  group('notificationDestination', () {
    Map<String, dynamic> meta(String rideId) => {'rideId': rideId};

    test('sends ride and payment alerts to the right screen', () {
      expect(
        notificationDestination(
          type: NotificationTypes.rideStarted,
          metadata: meta('r1'),
          isDriver: false,
        ),
        '/ride/r1/tracking',
      );
      // A finished trip opens its receipt for both sides: the fare, the
      // transaction and the rating all live there.
      expect(
        notificationDestination(
          type: NotificationTypes.rideCompleted,
          metadata: meta('r1'),
          isDriver: true,
        ),
        '/ride/r1/details',
      );
      expect(
        notificationDestination(
          type: NotificationTypes.rideCompleted,
          metadata: meta('r1'),
          isDriver: false,
        ),
        '/ride/r1/details',
      );
      // Both payment alerts land on the trip's transaction.
      expect(
        notificationDestination(
          type: NotificationTypes.paymentSent,
          metadata: meta('r1'),
          isDriver: false,
        ),
        '/ride/r1/details',
      );
      expect(
        notificationDestination(
          type: NotificationTypes.paymentReceived,
          metadata: meta('r1'),
          isDriver: true,
        ),
        '/ride/r1/details',
      );
    });

    test('opens the chat for a message alert', () {
      expect(
        notificationDestination(
          type: NotificationTypes.message,
          metadata: meta('r1'),
          isDriver: true,
        ),
        '/ride/r1/tracking?chat=1',
      );
    });

    test('never sends a driver to a ride they have not accepted', () {
      // A new request is readable only through the home request list.
      expect(
        notificationDestination(
          type: NotificationTypes.rideRequest,
          metadata: meta('r1'),
          isDriver: true,
        ),
        '/home',
      );
    });

    test('stays read-only for announcements, cancellations and unknown kinds',
        () {
      for (final type in [
        NotificationTypes.announcement,
        NotificationTypes.safety,
        NotificationTypes.rideCancelled,
        'brand_new_type',
        null,
      ]) {
        expect(
          notificationDestination(
            type: type,
            metadata: meta('r1'),
            isDriver: false,
          ),
          isNull,
          reason: '$type should not navigate',
        );
      }
    });

    test('degrades to read-only when the ride id is missing', () {
      for (final type in [
        NotificationTypes.rideStarted,
        NotificationTypes.rideCompleted,
        NotificationTypes.paymentSent,
        NotificationTypes.paymentReceived,
        NotificationTypes.message,
      ]) {
        expect(
          notificationDestination(type: type, metadata: null, isDriver: false),
          isNull,
        );
        expect(
          notificationDestination(
            type: type,
            metadata: const {'rideId': ''},
            isDriver: true,
          ),
          isNull,
        );
      }
    });
  });
}
