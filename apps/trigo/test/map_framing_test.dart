import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/municipality_locator.dart';

/// The map must frame exactly two points: the current starting point and the
/// destination of the leg being travelled.
///
///   driver on the way  -> driver's live position <-> passenger pickup
///   trip under way     -> driver's live position <-> drop-off
///
/// The drop-off must NOT be included on the pickup leg; doing so dragged both
/// the centre and the zoom toward a distant destination.
void main() {
  /// Mirrors RideTrackingMapView._activeLegPoints.
  List<(double lat, double lng)> activeLegPoints({
    required bool isDriver,
    required String? status,
    double? drvLat,
    double? drvLng,
    double? pLat,
    double? pLng,
    double? dLat,
    double? dLng,
  }) {
    final headingToPickup = status == 'accepted' || status == 'driver_arriving';
    final driverPoint =
        (drvLat != null && drvLng != null) ? (drvLat, drvLng) : null;

    if (headingToPickup) {
      final pickup = (pLat != null && pLng != null) ? (pLat, pLng) : null;
      return [
        if (driverPoint != null) driverPoint,
        if (pickup != null) pickup,
      ];
    }

    final dropoff = (dLat != null && dLng != null) ? (dLat, dLng) : null;
    return [
      if (driverPoint != null) driverPoint,
      if (dropoff != null) dropoff,
    ];
  }

  /// Mirrors the midpoint + zoom used when framing a leg.
  ({double centerLat, double centerLng, double spanKm}) frame(
    List<(double lat, double lng)> pts,
  ) {
    final a = pts.first;
    final b = pts.last;
    return (
      centerLat: (a.$1 + b.$1) / 2,
      centerLng: (a.$2 + b.$2) / 2,
      spanKm: haversineKm(a.$1, a.$2, b.$1, b.$2),
    );
  }

  // Driver en route; drop-off far away to the north-east.
  const drvLat = 10.250, drvLng = 123.940;
  const pLat = 10.256, pLng = 123.946;
  const dLat = 10.400, dLng = 124.100;

  group('driver on the way: frames driver + pickup only', () {
    test('exactly two points, and neither is the drop-off', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'accepted',
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(pts.length, 2);
      expect(pts, contains((drvLat, drvLng)));
      expect(pts, contains((pLat, pLng)));
      expect(pts, isNot(contains((dLat, dLng))),
          reason: 'the drop-off must not be framed on the pickup leg');
    });

    test('the centre sits between the driver and pickup, not the drop-off', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'accepted',
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      final r = frame(pts);

      expect(r.centerLat, closeTo((drvLat + pLat) / 2, 1e-9));
      // Far from the midpoint that including the drop-off would produce.
      const withDropoff = (drvLat + dLat) / 2;
      expect((r.centerLat - withDropoff).abs(), greaterThan(0.05));
    });

    test('the span is the short driver-to-pickup hop', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'accepted',
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      final r = frame(pts);
      final toDropoff = haversineKm(drvLat, drvLng, dLat, dLng);

      expect(r.spanKm, closeTo(haversineKm(drvLat, drvLng, pLat, pLng), 1e-9));
      expect(r.spanKm, lessThan(toDropoff / 5),
          reason: 'a distant drop-off must not force a wide zoom');
    });
  });

  group('trip under way: frames driver + drop-off', () {
    test('exactly two points: driver position and drop-off', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'in_progress',
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(pts.length, 2);
      expect(pts, contains((drvLat, drvLng)));
      expect(pts, contains((dLat, dLng)));
      expect(pts, isNot(contains((pLat, pLng))),
          reason: 'the pickup is behind them once the trip is under way');
    });

    test('the start point follows the driver as they move', () {
      final start = activeLegPoints(
        isDriver: true,
        status: 'in_progress',
        drvLat: drvLat,
        drvLng: drvLng,
        dLat: dLat,
        dLng: dLng,
      );
      final later = activeLegPoints(
        isDriver: true,
        status: 'in_progress',
        drvLat: drvLat + 0.01,
        drvLng: drvLng + 0.01,
        dLat: dLat,
        dLng: dLng,
      );
      expect(start.first, (drvLat, drvLng));
      expect(later.first, (drvLat + 0.01, drvLng + 0.01),
          reason: 'framing must follow the live position');
    });

    test('driver_arriving is still the pickup leg', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'driver_arriving',
        drvLat: drvLat,
        drvLng: drvLng,
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(pts, contains((pLat, pLng)));
      expect(pts, isNot(contains((dLat, dLng))));
    });
  });

  group('missing coordinates degrade gracefully', () {
    test('pickup leg with no driver fix frames the pickup alone', () {
      final pts = activeLegPoints(
        isDriver: true,
        status: 'accepted',
        pLat: pLat,
        pLng: pLng,
        dLat: dLat,
        dLng: dLng,
      );
      expect(pts.length, 1);
      expect(pts.first, (pLat, pLng));
    });

    test('no coordinates at all yields an empty list', () {
      expect(activeLegPoints(isDriver: true, status: 'accepted'), isEmpty);
      expect(activeLegPoints(isDriver: true, status: 'in_progress'), isEmpty);
    });
  });
}
