import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Represents a geocoding search result with name, address, and coordinates.
class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  String get fullAddress => subtitle.isNotEmpty ? '$title, $subtitle' : title;
}

/// Geocoding service with Mapbox API integration and fallback to Photon/OpenStreetMap.
class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  String? get _mapboxToken => dotenv.env['MAPBOX_PUBLIC_TOKEN'];

  /// Searches for places matching [query] with optional proximity bias.
  Future<List<LocationSearchResult>> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 2) return [];

    final token = _mapboxToken;
    if (token != null && token.isNotEmpty) {
      try {
        final proximity = (proximityLat != null && proximityLng != null)
            ? '&proximity=$proximityLng,$proximityLat'
            : '';
        final url =
            'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(trimmed)}.json?access_token=$token&country=PH&types=poi,address,neighborhood,locality,place$proximity';

        final response = await _dio.get(url);
        if (response.statusCode == 200 && response.data != null) {
          final features = response.data['features'] as List<dynamic>? ?? [];
          final results = <LocationSearchResult>[];

          for (final f in features) {
            final text = (f['text'] ?? '').toString();
            final placeName = (f['place_name'] ?? '').toString();
            final center = f['center'] as List<dynamic>?;
            if (center != null && center.length >= 2) {
              final lng = (center[0] as num).toDouble();
              final lat = (center[1] as num).toDouble();
              final subtitle = placeName.startsWith(text)
                  ? placeName.substring(text.length).replaceFirst(RegExp(r'^,\s*'), '')
                  : placeName;

              results.add(LocationSearchResult(
                title: text.isNotEmpty ? text : placeName,
                subtitle: subtitle,
                latitude: lat,
                longitude: lng,
              ));
            }
          }
          if (results.isNotEmpty) return results;
        }
      } catch (_) {
        // Fall back to Photon
      }
    }

    // Photon (OSM-based) fallback
    try {
      final proxParam = (proximityLat != null && proximityLng != null)
          ? '&lat=$proximityLat&lon=$proximityLng'
          : '';
      final url =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&limit=6$proxParam';
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final features = response.data['features'] as List<dynamic>? ?? [];
        final results = <LocationSearchResult>[];

        for (final f in features) {
          final props = f['properties'] as Map<String, dynamic>? ?? {};
          final geom = f['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>?;

          if (coords != null && coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final name = (props['name'] ?? props['street'] ?? trimmed).toString();
            final city = (props['city'] ?? props['county'] ?? props['state'] ?? 'Philippines').toString();

            results.add(LocationSearchResult(
              title: name,
              subtitle: city,
              latitude: lat,
              longitude: lng,
            ));
          }
        }
        return results;
      }
    } catch (_) {
      // Return empty list if all fail
    }

    return [];
  }

  /// Reverse geocodes coordinates to a human-readable address.
  Future<String> reverseGeocode(double lat, double lng) async {
    final token = _mapboxToken;
    if (token != null && token.isNotEmpty) {
      try {
        final url =
            'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$token&country=PH&types=poi,address,neighborhood,locality,place';
        final response = await _dio.get(url);
        if (response.statusCode == 200 && response.data != null) {
          final features = response.data['features'] as List<dynamic>? ?? [];
          if (features.isNotEmpty) {
            final first = features.first;
            return (first['place_name'] ?? first['text'] ?? '').toString();
          }
        }
      } catch (_) {}
    }

    // Fallback to coordinates format
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}
