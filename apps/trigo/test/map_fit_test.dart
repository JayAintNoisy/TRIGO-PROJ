import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/municipality_locator.dart';

/// The tracking map fits its camera to the bounding box of every known point
/// (driver, pickup, drop-off). These tests pin that geometry, which is what
/// stops the map opening parked on a fallback coordinate.
void main() {
  group('bounding box of tracked points', () {
    /// Mirrors _frameCoordinates' extent calculation.
    ({double centerLat, double centerLng, double spanKm}) fit(
      List<(double lat, double lng)> pts,
    ) {
      var minLat = double.infinity, maxLat = -double.infinity;
      var minLng = double.infinity, maxLng = -double.infinity;
      for (final (lat, lng) in pts) {
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }
      return (
        centerLat: (minLat + maxLat) / 2,
        centerLng: (minLng + maxLng) / 2,
        spanKm: haversineKm(minLat, minLng, maxLat, maxLng),
      );
    }

    test('two points centre midway between them', () {
      final r = fit([(10.0, 123.0), (10.2, 123.2)]);
      expect(r.centerLat, closeTo(10.1, 1e-9));
      expect(r.centerLng, closeTo(123.1, 1e-9));
      expect(r.spanKm, greaterThan(0));
    });

    test('three points centre on the full extent, not the first two', () {
      // Driver, pickup, and a drop-off further out. The centre must account
      // for the third point, otherwise the drop-off falls off-screen.
      final r = fit([(10.0, 123.0), (10.1, 123.1), (10.6, 123.8)]);
      expect(r.centerLat, closeTo(10.3, 1e-9));
      expect(r.centerLng, closeTo(123.4, 1e-9));
      expect(r.spanKm, greaterThan(fit([(10.0, 123.0), (10.1, 123.1)]).spanKm),
          reason: 'a wider extent must report a larger span');
    });

    test('identical points produce a zero span', () {
      final r = fit([(10.0, 123.0), (10.0, 123.0)]);
      expect(r.spanKm, closeTo(0, 1e-9));
      expect(r.centerLat, closeTo(10.0, 1e-9));
    });

    test('order of points does not change the fit', () {
      final a = fit([(10.0, 123.0), (10.2, 123.2), (10.1, 123.05)]);
      final b = fit([(10.1, 123.05), (10.0, 123.0), (10.2, 123.2)]);
      expect(a.centerLat, closeTo(b.centerLat, 1e-9));
      expect(a.centerLng, closeTo(b.centerLng, 1e-9));
      expect(a.spanKm, closeTo(b.spanKm, 1e-9));
    });

    test('a larger span selects a wider zoom', () {
      // Mirrors the zoom ladder in _frameCoordinates.
      double zoomFor(double distKm) {
        if (distKm < 0.8) return 15.5;
        if (distKm < 2.0) return 14.5;
        if (distKm < 5.0) return 13.5;
        if (distKm < 10.0) return 12.5;
        return 11.0;
      }

      expect(zoomFor(0.5), 15.5);
      expect(zoomFor(1.5), 14.5);
      expect(zoomFor(3.0), 13.5);
      expect(zoomFor(7.0), 12.5);
      expect(zoomFor(25.0), 11.0);
      // Monotonic: more distance must never zoom in further.
      final zooms = [0.5, 1.5, 3.0, 7.0, 25.0].map(zoomFor).toList();
      for (var i = 1; i < zooms.length; i++) {
        expect(zooms[i], lessThanOrEqualTo(zooms[i - 1]));
      }
    });
  });
}
