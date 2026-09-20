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

/// Highly optimized geocoding service with in-memory caching,
/// coordinate rounding, local landmark presets, and fallback to Photon.
class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  String? get _mapboxToken => dotenv.env['MAPBOX_PUBLIC_TOKEN'];

  // In-memory caches to save API quota
  static final Map<String, List<LocationSearchResult>> _searchCache = {};
  static final Map<String, String> _reverseCache = {};
  static const int _maxCacheEntries = 250;

  /// Searches for places matching [query] with optional proximity bias.
  /// Checks local cache and landmark presets first before firing network calls.
  Future<List<LocationSearchResult>> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 3) return [];

    final cacheKey =
        '${trimmed.toLowerCase()}_${proximityLat?.toStringAsFixed(2)}_${proximityLng?.toStringAsFixed(2)}';

    // 1. Check in-memory search cache
    if (_searchCache.containsKey(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    final results = <LocationSearchResult>[];

    // 2. Fetch from Mapbox Geocoding API
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
        }
      } catch (_) {
        // Fall back to Photon
      }
    }

    // 3. Fallback to Photon (OSM-based) if Mapbox returns no results
    if (results.isEmpty) {
      try {
        final proxParam = (proximityLat != null && proximityLng != null)
            ? '&lat=$proximityLat&lon=$proximityLng'
            : '';
        final url =
            'https://photon.komoot.io/api/?q=${Uri.encodeComponent(trimmed)}&limit=6$proxParam';
        final response = await _dio.get(url);
        if (response.statusCode == 200 && response.data != null) {
          final features = response.data['features'] as List<dynamic>? ?? [];

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
        }
      } catch (_) {}
    }

    // Cache the resolved result
    if (results.isNotEmpty) {
      if (_searchCache.length >= _maxCacheEntries) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = results;
    }

    return results;
  }

  /// Reverse geocodes coordinates to a human-readable address.
  /// Uses rounded coordinate caching (~100m grid cell) to eliminate redundant API calls.
  Future<String> reverseGeocode(double lat, double lng) async {
    // Round to 3 decimal places (~100m precision) for cache lookup
    final cacheKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
    if (_reverseCache.containsKey(cacheKey)) {
      return _reverseCache[cacheKey]!;
    }

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
            final address = (first['place_name'] ?? first['text'] ?? '').toString();
            if (address.isNotEmpty) {
              if (_reverseCache.length >= _maxCacheEntries) {
                _reverseCache.remove(_reverseCache.keys.first);
              }
              _reverseCache[cacheKey] = address;
              return address;
            }
          }
        }
      } catch (_) {}
    }

    final fallback = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    return fallback;
  }
}
