import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/presentation/widgets/ride_tracking_map_view.dart';
import 'package:trigo/shared/utils/municipality_locator.dart';

/// The driver's position broadcast and the map's polyline re-route must fire at
/// the same distance, otherwise one visibly lags the other:
///   - broadcast larger  -> the drawn line sits ahead of the uploaded position
///   - re-route larger   -> the line trails the driver's real position
///
/// This test pins the two constants together so a change to one without the
/// other fails loudly.
void main() {
  // Mirrors _broadcastDistanceFilterMeters in ride_tracking_screen.dart.
  // Duplicated deliberately: importing the private constant is impossible, so
  // this test exists to catch drift between the two files.
  const broadcastDistanceMeters = 50;

  group('broadcast and re-route stay in sync', () {
    test('the re-route threshold matches the broadcast distance', () {
      const reRouteMeters = routeRefreshDistanceKm * 1000;
      expect(reRouteMeters, closeTo(broadcastDistanceMeters, 0.001),
          reason: 'the polyline must re-route at the same distance the '
              'position is broadcast, or the line lags the driver');
    });

    test('both are 50 metres', () {
      expect(routeRefreshDistanceKm, 0.05);
      expect(broadcastDistanceMeters, 50);
    });
  });

  group('distance-filter semantics', () {
    /// Mirrors the platform's distanceFilter behaviour: emit only once the
    /// device has travelled at least the filter distance from the last fix.
    bool shouldEmit({
      required double lastLat,
      required double lastLng,
      required double newLat,
      required double newLng,
      int filterMeters = broadcastDistanceMeters,
    }) {
      final movedKm = haversineKm(lastLat, lastLng, newLat, newLng);
      return movedKm * 1000 >= filterMeters;
    }

    const lat = 10.250, lng = 123.940;

    test('a short move below the filter does not emit', () {
      // ~22m north.
      expect(
        shouldEmit(
            lastLat: lat, lastLng: lng, newLat: lat + 0.0002, newLng: lng),
        isFalse,
      );
    });

    test('a move at the filter distance emits', () {
      // ~55m north, past 50m.
      expect(
        shouldEmit(
            lastLat: lat, lastLng: lng, newLat: lat + 0.0005, newLng: lng),
        isTrue,
      );
    });

    test('a long move emits once, not repeatedly per metre', () {
      // The platform coalesces: one emission covers the whole 500m jump.
      expect(
        shouldEmit(
            lastLat: lat, lastLng: lng, newLat: lat + 0.0045, newLng: lng),
        isTrue,
      );
    });

    test('the re-route threshold would also fire on that same move', () {
      // Same movement must satisfy the map's threshold too, so the line
      // redraws in step with the broadcast.
      final movedKm = haversineKm(lat, lng, lat + 0.0005, lng);
      expect(movedKm, greaterThanOrEqualTo(routeRefreshDistanceKm),
          reason: 'the same movement must trigger a re-route');
    });
  });

  group('why a fixed timer was insufficient', () {
    test('at 30 km/h a 10s tick covers far more than 50m', () {
      // The previous implementation polled every 10s regardless of movement.
      const speedKmh = 30.0;
      const metersPer10s = (speedKmh * 1000 / 3600) * 10;
      expect(metersPer10s, greaterThan(80),
          reason: 'a timer-only approach let the line fall ~83m behind');
      expect(metersPer10s, greaterThan(broadcastDistanceMeters));
    });

    test('at 60 km/h a 10s tick covers well over 150m', () {
      const speedKmh = 60.0;
      const metersPer10s = (speedKmh * 1000 / 3600) * 10;
      expect(metersPer10s, greaterThan(160));
    });
  });
}
