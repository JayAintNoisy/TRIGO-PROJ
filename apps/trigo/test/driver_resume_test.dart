import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/data/rides_repository.dart';

/// A driver who restarts mid-trip must return to that trip rather than to the
/// idle "waiting for passengers" Home state.
///
/// The critical distinction from the customer flow: a `requested` ride has no
/// driver yet, so it is an open request belonging to the customer — never the
/// driver's ride to resume.
void main() {
  group('driver-assigned statuses', () {
    test('a driver is committed once they have accepted', () {
      expect(RidesRepository.isDriverAssignedStatus('accepted'), isTrue);
      expect(RidesRepository.isDriverAssignedStatus('driver_arriving'), isTrue);
      expect(RidesRepository.isDriverAssignedStatus('in_progress'), isTrue);
    });

    test('an unclaimed request is NOT the driver\'s ride', () {
      // This is the bug guard: resuming on 'requested' would drop a driver
      // into a ride nobody has accepted.
      expect(RidesRepository.isDriverAssignedStatus('requested'), isFalse);
      expect(RidesRepository.isActiveStatus('requested'), isTrue,
          reason: 'requested is still active for the *customer*');
    });

    test('terminal and unknown statuses are not resumable', () {
      for (final s in ['completed', 'cancelled', 'bogus', '', null]) {
        expect(RidesRepository.isDriverAssignedStatus(s), isFalse,
            reason: '$s must not resume a driver');
      }
    });

    test('driver-assigned is a strict subset of active', () {
      // Every status that resumes a driver must also be a ride the customer
      // would consider in-flight, otherwise the two views disagree.
      for (final s in RidesRepository.driverAssignedStatuses) {
        expect(RidesRepository.isActiveStatus(s), isTrue,
            reason: '$s must also be active for the customer');
      }
      expect(
        RidesRepository.driverAssignedStatuses.length,
        lessThan(RidesRepository.activeStatuses.length),
        reason: 'the driver set must exclude at least requested',
      );
    });
  });

  group('resume selection over a ride list', () {
    /// Mirrors RidesRepository.getDriverAssignedRide's selection rule.
    dynamic pickDriverRide(List<dynamic> rides) {
      for (final ride in rides) {
        if (ride is Map &&
            RidesRepository.isDriverAssignedStatus(
                ride['status']?.toString())) {
          return ride;
        }
      }
      return null;
    }

    /// Mirrors RidesRepository.getActiveRide's selection rule.
    dynamic pickCustomerRide(List<dynamic> rides) {
      for (final ride in rides) {
        if (ride is Map &&
            RidesRepository.isActiveStatus(ride['status']?.toString())) {
          return ride;
        }
      }
      return null;
    }

    test('driver resumes their in-progress ride, newest first', () {
      final rides = <dynamic>[
        {'id': 'newest', 'status': 'in_progress'},
        {'id': 'older', 'status': 'completed'},
      ];
      expect((pickDriverRide(rides) as Map)['id'], 'newest');
    });

    test('driver with only open requests stays idle', () {
      final rides = <dynamic>[
        {'id': 'open-1', 'status': 'requested'},
        {'id': 'open-2', 'status': 'requested'},
      ];
      expect(pickDriverRide(rides), isNull,
          reason: 'an unclaimed request must not resume the driver');
      // The customer, by contrast, does resume on their own requested ride.
      expect((pickCustomerRide(rides) as Map)['id'], 'open-1');
    });

    test('driver skips a completed ride to find the live one', () {
      final rides = <dynamic>[
        {'id': 'done', 'status': 'completed'},
        {'id': 'live', 'status': 'driver_arriving'},
      ];
      expect((pickDriverRide(rides) as Map)['id'], 'live');
    });

    test('driver with no rides resumes nothing', () {
      expect(pickDriverRide(<dynamic>[]), isNull);
    });

    test('malformed entries are skipped rather than throwing', () {
      final rides = <dynamic>[
        'not-a-map',
        42,
        {'id': 'live', 'status': 'accepted'},
      ];
      expect((pickDriverRide(rides) as Map)['id'], 'live');
    });

    test('a ride with no status does not resume', () {
      final rides = <dynamic>[
        {'id': 'no-status'},
        {'id': 'live', 'status': 'accepted'},
      ];
      expect((pickDriverRide(rides) as Map)['id'], 'live');
    });
  });
}
