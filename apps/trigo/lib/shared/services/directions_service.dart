import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Represents a routing solution between pickup and dropoff coordinates.
class DirectionsRoute {
  final List<Position> coordinates;
  final double distanceMeters;
  final double durationSeconds;

  const DirectionsRoute({
    required this.coordinates,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}

/// Service that fetches turn-by-turn driving polyline coordinates.
class DirectionsService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  String? get _mapboxToken => dotenv.env['MAPBOX_PUBLIC_TOKEN'];

  Future<DirectionsRoute?> getRoute({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final token = _mapboxToken;
    if (token != null && token.isNotEmpty) {
      try {
        final url =
            'https://api.mapbox.com/directions/v5/mapbox/driving/$pickupLng,$pickupLat;$dropoffLng,$dropoffLat?geometries=geojson&overview=full&access_token=$token';
        final response = await _dio.get(url);
        if (response.statusCode == 200 && response.data != null) {
          final routes = response.data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final first = routes.first as Map<String, dynamic>;
            final geometry = first['geometry'] as Map<String, dynamic>?;
            final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];
            final positions = <Position>[];

            for (final pair in rawCoords) {
              if (pair is List && pair.length >= 2) {
                final lng = (pair[0] as num).toDouble();
                final lat = (pair[1] as num).toDouble();
                positions.add(Position(lng, lat));
              }
            }

            if (positions.isNotEmpty) {
              return DirectionsRoute(
                coordinates: positions,
                distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
                durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0,
              );
            }
          }
        }
      } catch (_) {}
    }

    // OSRM fallback
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/$pickupLng,$pickupLat;$dropoffLng,$dropoffLat?geometries=geojson&overview=full';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final first = routes.first as Map<String, dynamic>;
          final geometry = first['geometry'] as Map<String, dynamic>?;
          final rawCoords = geometry?['coordinates'] as List<dynamic>? ?? [];
          final positions = <Position>[];

          for (final pair in rawCoords) {
            if (pair is List && pair.length >= 2) {
              final lng = (pair[0] as num).toDouble();
              final lat = (pair[1] as num).toDouble();
              positions.add(Position(lng, lat));
            }
          }

          if (positions.isNotEmpty) {
            return DirectionsRoute(
              coordinates: positions,
              distanceMeters: (first['distance'] as num?)?.toDouble() ?? 0,
              durationSeconds: (first['duration'] as num?)?.toDouble() ?? 0,
            );
          }
        }
      }
    } catch (_) {}

    // Direct line fallback
    return DirectionsRoute(
      coordinates: [
        Position(pickupLng, pickupLat),
        Position(dropoffLng, dropoffLat),
      ],
      distanceMeters: 0,
      durationSeconds: 0,
    );
  }
}
