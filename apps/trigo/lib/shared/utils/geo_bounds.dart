import 'package:turf/turf.dart';

/// An axis-aligned latitude/longitude box used to fence geocoding searches to
/// the TriGo service area.
///
/// Both geocoding providers accept the same `bbox` encoding
/// (`minLng,minLat,maxLng,maxLat`), exposed as [queryValue].
class GeoBounds {
  const GeoBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  /// A square box of roughly [halfDegrees] degrees in every direction.
  factory GeoBounds.fromCenter(
    double lat,
    double lng, {
    double halfDegrees = 0.3,
  }) {
    return GeoBounds(
      minLat: (lat - halfDegrees).clamp(-90.0, 90.0).toDouble(),
      minLng: (lng - halfDegrees).clamp(-180.0, 180.0).toDouble(),
      maxLat: (lat + halfDegrees).clamp(-90.0, 90.0).toDouble(),
      maxLng: (lng + halfDegrees).clamp(-180.0, 180.0).toDouble(),
    );
  }

  bool get isValid =>
      minLat.isFinite &&
      minLng.isFinite &&
      maxLat.isFinite &&
      maxLng.isFinite &&
      maxLat > minLat &&
      maxLng > minLng;

  bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  /// Smallest box covering both this box and [other].
  GeoBounds expandToInclude(GeoBounds other) {
    return GeoBounds(
      minLat: minLat < other.minLat ? minLat : other.minLat,
      minLng: minLng < other.minLng ? minLng : other.minLng,
      maxLat: maxLat > other.maxLat ? maxLat : other.maxLat,
      maxLng: maxLng > other.maxLng ? maxLng : other.maxLng,
    );
  }

  /// Grows the box only as far as needed so [lat]/[lng] falls inside, which
  /// keeps a degenerate single-point boundary ring from collapsing the fence.
  GeoBounds padToInclude(double lat, double lng, {double halfDegrees = 0.01}) {
    return GeoBounds(
      minLat: lat < minLat ? lat - halfDegrees : minLat,
      minLng: lng < minLng ? lng - halfDegrees : minLng,
      maxLat: lat > maxLat ? lat + halfDegrees : maxLat,
      maxLng: lng > maxLng ? lng + halfDegrees : maxLng,
    );
  }

  /// `minLng,minLat,maxLng,maxLat` — the `bbox` value shared by Mapbox and
  /// Photon (identical parameter name and order).
  String get queryValue => '$minLng,$minLat,$maxLng,$maxLat';
}

/// Bounding box covering every position of [rings], or null when the rings
/// carry no usable coordinates.
GeoBounds? boundsFromPolygonRings(List<List<Position>>? rings) {
  if (rings == null || rings.isEmpty) return null;

  var minLat = double.infinity;
  var minLng = double.infinity;
  var maxLat = -double.infinity;
  var maxLng = -double.infinity;
  var count = 0;

  for (final ring in rings) {
    for (final position in ring) {
      // turf's Position exposes lat/lng as num.
      final lat = position.lat.toDouble();
      final lng = position.lng.toDouble();
      if (!lat.isFinite || !lng.isFinite) continue;
      if (lat < minLat) minLat = lat;
      if (lng < minLng) minLng = lng;
      if (lat > maxLat) maxLat = lat;
      if (lng > maxLng) maxLng = lng;
      count++;
    }
  }

  if (count == 0) return null;

  final bounds = GeoBounds(
    minLat: minLat,
    minLng: minLng,
    maxLat: maxLat,
    maxLng: maxLng,
  );
  return bounds.isValid ? bounds : null;
}
