import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/municipality_locator.dart';

/// The remaining-distance badge shows two figures whose meaning depends on who
/// is looking:
///   driver    -> "To passenger" (driver->pickup) and "Total trip"
///                (driver->pickup->dropoff)
///   passenger -> "Driver distance" (driver->pickup) and "To destination"
///                (pickup->dropoff)
void main() {
  /// Mirrors RideTrackingMapView._remainingDistances' computation.
  ({
    double? primaryKm,
    String? primaryLabel,
    double? secondaryKm,
    String? secondaryLabel,
  }) distances({
    required bool isDriver,
    double? drvLat,
    double? drvLng,
    double? pLat,
    double? pLng,
    double? dLat,
    double? dLng,
  }) {
    final hasDriver = drvLat != null && drvLng != null;
    final hasPickup = pLat != null && pLng != null;
    final hasDropoff = dLat != null && dLng != null;

    final toPickup =
        hasDriver && hasPickup ? haversineKm(drvLat, drvLng, pLat, pLng) : null;
    final pickupToDropoff =
        hasPickup && hasDropoff ? haversineKm(pLat, pLng, dLat, dLng) : null;

    if (isDriver) {
      final totalTrip = (toPickup != null && pickupToDropoff != null)
          ? toPickup + pickupToDropoff
          : null;
      return (
        primaryKm: toPickup,
        primaryLabel: 'To passenger',
        secondaryKm: totalTrip,
        secondaryLabel: 'Total trip',
      );
    }

    return (
      primaryKm: toPickup,
      primaryLabel: 'Driver distance',
      secondaryKm: pickupToDropoff,
      secondaryLabel: 'To destination',
    );
  }

  // A small triangle: driver, pickup and drop-off all a short hop apart.
  const drvLat = 10.250, drvLng = 123.940;
  const pLat = 10.255, pLng = 123.945;
  const dLat = 10.262, dLng = 123.955;

  group('driver view', () {
    test('labels are "To passenger" and "Total trip"', () {
      final r = distances(
        isDriver: true,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(r.primaryLabel, 'To passenger');
      expect(r.secondaryLabel, 'Total trip');
    });

    test('total trip is the sum of both legs, not a single hop', () {
      final r = distances(
        isDriver: true,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      final legToPickup = haversineKm(drvLat, drvLng, pLat, pLng);
      final legToDropoff = haversineKm(pLat, pLng, dLat, dLng);

      expect(r.primaryKm, closeTo(legToPickup, 1e-9));
      expect(r.secondaryKm, closeTo(legToPickup + legToDropoff, 1e-9));
      expect(r.secondaryKm! > r.primaryKm!, isTrue,
          reason: 'the whole trip must exceed the leg to the passenger');
    });
  });

  group('passenger view', () {
    test('labels are "Driver distance" and "To destination"', () {
      final r = distances(
        isDriver: false,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(r.primaryLabel, 'Driver distance');
      expect(r.secondaryLabel, 'To destination');
    });

    test('second figure is only the passenger-to-destination leg', () {
      final r = distances(
        isDriver: false,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(r.secondaryKm, closeTo(haversineKm(pLat, pLng, dLat, dLng), 1e-9));
      // Distinct from the driver's total-trip figure for the same points.
      final driverView = distances(
        isDriver: true,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(r.secondaryKm, lessThan(driverView.secondaryKm!));
    });
  });

  group('missing coordinates', () {
    test('no driver fix hides the primary figure but keeps the trip leg', () {
      final r = distances(
        isDriver: false,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(r.primaryKm, isNull, reason: 'cannot measure without a driver');
      expect(r.secondaryKm, isNotNull);
    });

    test('driver view has no total trip until both legs are known', () {
      final r = distances(
        isDriver: true,
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
      );
      expect(r.primaryKm, isNotNull);
      expect(r.secondaryKm, isNull,
          reason: 'the total trip needs the drop-off too');
    });

    test('no coordinates at all yields two nulls, never a fake value', () {
      final r = distances(isDriver: true);
      expect(r.primaryKm, isNull);
      expect(r.secondaryKm, isNull);
    });
  });
}
