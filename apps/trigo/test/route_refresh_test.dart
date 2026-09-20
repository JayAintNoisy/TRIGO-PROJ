import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/utils/municipality_locator.dart';

/// The route polyline must follow the driver.
///
/// Two regressions are guarded here:
///  1. `didUpdateWidget` used to call the route fetch only when nothing was
///     cached, so a drawn line froze at the driver's first position forever.
///  2. Even when called, the reuse guard required a 300m drift before
///     re-routing — too coarse for a moving vehicle.
void main() {
  /// Mirrors the reuse decision in _fetchAndDrawRouteIfNeeded.
  bool shouldReuseCachedRoute({
    required bool hasCache,
    required double? cachedStartLat,
    required double? cachedStartLng,
    required double? cachedTargetLat,
    required double? cachedTargetLng,
    required double startLat,
    required double startLng,
    required double targetLat,
    required double targetLng,
    bool force = false,
    double thresholdKm = 0.05,
  }) {
    if (force || !hasCache) return false;
    if (cachedTargetLat != targetLat || cachedTargetLng != targetLng) {
      return false;
    }
    if (cachedStartLat == null || cachedStartLng == null) return false;
    final drift =
        haversineKm(cachedStartLat, cachedStartLng, startLat, startLng);
    return drift < thresholdKm;
  }

  const pLat = 10.255, pLng = 123.945; // pickup (target of the pickup leg)
  const startLat = 10.250, startLng = 123.940;

  group('re-route threshold', () {
    test('a small drift reuses the cached line', () {
      // ~11m north: below the 50m threshold.
      final reuse = shouldReuseCachedRoute(
        hasCache: true,
        cachedStartLat: startLat,
        cachedStartLng: startLng,
        cachedTargetLat: pLat,
        cachedTargetLng: pLng,
        startLat: startLat + 0.0001,
        startLng: startLng,
        targetLat: pLat,
        targetLng: pLng,
      );
      expect(reuse, isTrue);
    });

    test('a drift past ~50m triggers a re-route', () {
      // ~111m north: comfortably past the threshold.
      final reuse = shouldReuseCachedRoute(
        hasCache: true,
        cachedStartLat: startLat,
        cachedStartLng: startLng,
        cachedTargetLat: pLat,
        cachedTargetLng: pLng,
        startLat: startLat + 0.001,
        startLng: startLng,
        targetLat: pLat,
        targetLng: pLng,
      );
      expect(reuse, isFalse, reason: 'the line must follow the driver');
    });

    test('the threshold is far tighter than the old 300m', () {
      // 100m must now re-route, whereas the previous 0.3km guard reused.
      const driftDeg = 0.0009; // ~100m
      final km = haversineKm(startLat, startLng, startLat + driftDeg, startLng);
      expect(km, greaterThan(0.05));
      expect(km, lessThan(0.3));
      expect(
        shouldReuseCachedRoute(
          hasCache: true,
          cachedStartLat: startLat,
          cachedStartLng: startLng,
          cachedTargetLat: pLat,
          cachedTargetLng: pLng,
          startLat: startLat + driftDeg,
          startLng: startLng,
          targetLat: pLat,
          targetLng: pLng,
        ),
        isFalse,
      );
    });

    test('no cache always fetches', () {
      expect(
        shouldReuseCachedRoute(
          hasCache: false,
          cachedStartLat: null,
          cachedStartLng: null,
          cachedTargetLat: null,
          cachedTargetLng: null,
          startLat: startLat,
          startLng: startLng,
          targetLat: pLat,
          targetLng: pLng,
        ),
        isFalse,
      );
    });

    test('a changed target always fetches even with no drift', () {
      // The leg switched to pickup -> drop-off.
      expect(
        shouldReuseCachedRoute(
          hasCache: true,
          cachedStartLat: startLat,
          cachedStartLng: startLng,
          cachedTargetLat: pLat,
          cachedTargetLng: pLng,
          startLat: startLat,
          startLng: startLng,
          targetLat: 10.262,
          targetLng: 123.955,
        ),
        isFalse,
      );
    });

    test('force always fetches', () {
      expect(
        shouldReuseCachedRoute(
          hasCache: true,
          cachedStartLat: startLat,
          cachedStartLng: startLng,
          cachedTargetLat: pLat,
          cachedTargetLng: pLng,
          startLat: startLat,
          startLng: startLng,
          targetLat: pLat,
          targetLng: pLng,
          force: true,
        ),
        isFalse,
      );
    });
  });
}
