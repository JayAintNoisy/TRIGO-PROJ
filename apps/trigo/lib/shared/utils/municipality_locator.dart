import 'dart:convert';
import 'dart:math' as math;

import 'package:turf/turf.dart';

class MunicipalityMatch {
  final String id;
  final String name;
  final String? province;
  final double centerLat;
  final double centerLng;
  final double radiusKm;
  final dynamic boundaryGeojson;

  const MunicipalityMatch({
    required this.id,
    required this.name,
    this.province,
    required this.centerLat,
    required this.centerLng,
    required this.radiusKm,
    this.boundaryGeojson,
  });
}

const double _earthRadiusKm = 6371.0;

/// Great-circle distance between two coordinates in kilometres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  double toRad(double deg) => deg * math.pi / 180.0;
  final sinLat = math.sin(toRad(lat2 - lat1) / 2);
  final sinLng = math.sin(toRad(lng2 - lng1) / 2);
  final a = sinLat * sinLat +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * sinLng * sinLng;
  return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
}

/// Helper to parse polygon coordinates from GeoJSON or coordinate list.
/// Supports Map, List, or JSON-encoded string.
/// Ensures the polygon ring is strictly closed (first position == last position).
List<List<Position>>? extractPolygonRings(dynamic boundaryGeojson) {
  if (boundaryGeojson == null) return null;
  try {
    dynamic parsed = boundaryGeojson;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {}
    }

    List<dynamic>? rawList;
    if (parsed is Map) {
      final type = parsed['type'];
      final coords = parsed['coordinates'];
      if (type == 'Polygon' && coords is List && coords.isNotEmpty) {
        rawList = coords.first as List;
      }
    } else if (parsed is List && parsed.isNotEmpty) {
      rawList = parsed;
    }

    if (rawList != null && rawList.length >= 3) {
      final positions = <Position>[];
      for (final pt in rawList) {
        if (pt is List && pt.length >= 2) {
          positions.add(Position(
            (pt[0] as num).toDouble(),
            (pt[1] as num).toDouble(),
          ));
        }
      }

      if (positions.length >= 3) {
        // Mapbox and GeoJSON strictly require the first and last position to be identical
        if (positions.first.lat != positions.last.lat ||
            positions.first.lng != positions.last.lng) {
          positions.add(Position(positions.first.lng, positions.first.lat));
        }
        return [positions];
      }
    }
  } catch (_) {}
  return null;
}

/// Checks strictly whether a coordinate (lat, lng) lies inside a municipality's
/// polygon boundary.
bool isPointInsideMunicipality(double lat, double lng, dynamic municipality) {
  if (municipality == null) return false;
  final match = municipality is MunicipalityMatch
      ? municipality
      : (municipality is Map ? matchFromMunicipalityMap(municipality) : null);
  if (match == null) return false;

  final customRings = extractPolygonRings(match.boundaryGeojson);
  if (customRings != null && customRings.isNotEmpty) {
    try {
      final polygon = Polygon(coordinates: customRings);
      final pos = Position(lng, lat);
      return booleanPointInPolygon(pos, polygon);
    } catch (_) {
      return false;
    }
  }

  // If no polygon geometry defined at all, fall back to radius
  final dist = haversineKm(lat, lng, match.centerLat, match.centerLng);
  return dist <= match.radiusKm;
}

/// Nearest active municipality whose boundary contains the point,
/// checking custom polygon geometry first, then falling back to circular radius.
MunicipalityMatch? locateMunicipality(
  double lat,
  double lng,
  List<dynamic> municipalities,
) {
  MunicipalityMatch? best;
  var bestDistance = double.infinity;

  for (final m in municipalities) {
    if (m is! Map) continue;
    final match = matchFromMunicipalityMap(m);
    if (match == null) continue;

    final distance =
        haversineKm(lat, lng, match.centerLat, match.centerLng);

    // Check custom polygon containment if available
    final customRings = extractPolygonRings(match.boundaryGeojson);
    if (customRings != null && customRings.isNotEmpty) {
      try {
        final polygon = Polygon(coordinates: customRings);
        final pos = Position(lng, lat);
        if (booleanPointInPolygon(pos, polygon)) {
          if (distance < bestDistance) {
            bestDistance = distance;
            best = match;
          }
        }
      } catch (_) {}
      continue;
    }

    // Fallback to circular radius
    if (distance <= match.radiusKm && distance < bestDistance) {
      bestDistance = distance;
      best = match;
    }
  }
  return best;
}

/// First parseable municipality in the list, regardless of containment.
MunicipalityMatch? firstMunicipality(List<dynamic> municipalities) {
  for (final m in municipalities) {
    if (m is! Map) continue;
    final match = matchFromMunicipalityMap(m);
    if (match != null) return match;
  }
  return null;
}

MunicipalityMatch? matchFromMunicipalityMap(Map m) {
  final id = m['id'];
  final name = m['name'];
  final centerLat = (m['centerLat'] as num?)?.toDouble() ??
      (m['center_lat'] as num?)?.toDouble();
  final centerLng = (m['centerLng'] as num?)?.toDouble() ??
      (m['center_lng'] as num?)?.toDouble();
  final radiusKm = (m['radiusKm'] as num?)?.toDouble() ??
      (m['radius_km'] as num?)?.toDouble() ??
      10.0;
  if (id is! String || name is! String) return null;
  if (centerLat == null || centerLng == null) {
    return null;
  }
  return MunicipalityMatch(
    id: id,
    name: name,
    province: m['province'] as String?,
    centerLat: centerLat,
    centerLng: centerLng,
    radiusKm: radiusKm,
    boundaryGeojson: m['boundaryGeojson'] ?? m['boundary_geojson'],
  );
}

/// Returns the boundary polygon rings for a municipality, using its custom
/// geometry if present, or generating a geodesic circular ring.
List<List<Position>> getMunicipalityBoundaryRings(MunicipalityMatch match) {
  final customRings = extractPolygonRings(match.boundaryGeojson);
  if (customRings != null && customRings.isNotEmpty) {
    return customRings;
  }

  return boundaryRing(
    centerLat: match.centerLat,
    centerLng: match.centerLng,
    radiusKm: match.radiusKm,
  );
}

/// Geographic circle around a point as a closed polygon ring, suitable for
/// drawing municipality boundary radii on a map.
List<List<Position>> boundaryRing({
  required double centerLat,
  required double centerLng,
  required double radiusKm,
  int steps = 64,
}) {
  final angular = radiusKm / _earthRadiusKm;
  final latRad = centerLat * math.pi / 180.0;
  final lngRad = centerLng * math.pi / 180.0;
  final points = <Position>[];
  for (var i = 0; i <= steps; i++) {
    final bearing = 2 * math.pi * i / steps;
    final lat2 = math.asin(
      math.sin(latRad) * math.cos(angular) +
          math.cos(latRad) * math.sin(angular) * math.cos(bearing),
    );
    final lng2 = lngRad +
        math.atan2(
          math.sin(bearing) * math.sin(angular) * math.cos(latRad),
          math.cos(angular) - math.sin(latRad) * math.sin(lat2),
        );
    points.add(Position(
      lng2 * 180.0 / math.pi,
      lat2 * 180.0 / math.pi,
    ));
  }
  return [points];
}
