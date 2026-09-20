import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/data/rides_repository.dart';
import 'package:trigo/features/ride_booking/presentation/widgets/ride_tracking_map_view.dart';

/// The tracking map decides which leg to route from the ride status: while the
/// driver is on the way it routes driver -> passenger pickup; once the trip is
/// under way it routes pickup -> drop-off.
///
/// These assertions call the real [isPickupLegStatus] so a rename on either
/// side fails loudly instead of silently reverting to a two-point map.
void main() {
  group('ride leg selection', () {
    test('accepted and driver_arriving are the pickup leg', () {
      expect(isPickupLegStatus('accepted'), isTrue);
      expect(isPickupLegStatus('driver_arriving'), isTrue);
    });

    test('in_progress and terminal statuses are the trip leg', () {
      expect(isPickupLegStatus('in_progress'), isFalse);
      expect(isPickupLegStatus('completed'), isFalse);
      expect(isPickupLegStatus('cancelled'), isFalse);
      expect(isPickupLegStatus('requested'), isFalse);
      expect(isPickupLegStatus(null), isFalse);
    });

    test('all four in-flight statuses are recognised as active', () {
      // The statuses the map can be asked to render must all be "active",
      // otherwise a resumed ride would not reach the tracking screen.
      for (final s in [
        'requested',
        'accepted',
        'driver_arriving',
        'in_progress'
      ]) {
        expect(RidesRepository.isActiveStatus(s), isTrue,
            reason: '$s must count as active');
      }
    });

    test('terminal statuses never select a leg', () {
      for (final s in ['completed', 'cancelled']) {
        expect(isPickupLegStatus(s), isFalse);
        expect(RidesRepository.isActiveStatus(s), isFalse);
      }
    });
  });

  group('driver coordinates on the ride payload', () {
    test('driverLat/driverLng are read as nullable numbers', () {
      // The map treats a missing driver fix as "fall back to pickup", so a
      // null payload must not throw.
      final withCoords = <String, dynamic>{
        'driverLat': 10.25,
        'driverLng': 123.94,
      };
      final withoutCoords = <String, dynamic>{
        'driverLat': null,
        'driverLng': null,
      };

      expect((withCoords['driverLat'] as num?)?.toDouble(), 10.25);
      expect((withoutCoords['driverLat'] as num?)?.toDouble(), isNull);
      expect((withCoords['driverLng'] as num?)?.toDouble(), 123.94);
      expect((withoutCoords['driverLng'] as num?)?.toDouble(), isNull);
    });

    test('an absent driver key yields null rather than throwing', () {
      final payload = <String, dynamic>{'id': 'r1', 'status': 'accepted'};
      expect((payload['driverLat'] as num?)?.toDouble(), isNull);
      expect((payload['driverLng'] as num?)?.toDouble(), isNull);
    });
  });
}
