import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/geo_bounds.dart';

/// What kind of place a [LocationSearchResult] describes.
///
/// Drives ranking (a named landmark outranks an administrative area that
/// matches the query just as well) and the icon shown in the suggestion list.
enum PlaceCategory {
  school,
  hospital,
  market,
  worship,
  government,
  transit,
  shop,
  food,
  lodging,
  park,
  landmark,
  address,
  street,
  neighborhood,
  locality,
  place,
  region,
  unknown;

  static const Set<PlaceCategory> _poiCategories = {
    PlaceCategory.school,
    PlaceCategory.hospital,
    PlaceCategory.market,
    PlaceCategory.worship,
    PlaceCategory.government,
    PlaceCategory.transit,
    PlaceCategory.shop,
    PlaceCategory.food,
    PlaceCategory.lodging,
    PlaceCategory.park,
    PlaceCategory.landmark,
  };

  /// A specific, nameable place (school, market, church, shop, ...) as opposed
  /// to an address, a street, or an administrative area such as a barangay.
  bool get isPoi => _poiCategories.contains(this);
}

/// Represents a geocoding search result with name, address, and coordinates.
class LocationSearchResult {
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final PlaceCategory category;

  /// Which provider produced this result ('mapbox', 'photon', or 'map').
  final String source;

  const LocationSearchResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.category = PlaceCategory.unknown,
    this.source = 'unknown',
  });

  String get fullAddress => subtitle.isNotEmpty ? '$title, $subtitle' : title;
}

/// Outcome of a forward search.
class LocationSearchOutcome {
  const LocationSearchOutcome({
    required this.results,
    this.landmarkSourceFailed = false,
  });

  final List<LocationSearchResult> results;

  /// True when the landmark provider could not be reached, so [results] is
  /// likely limited to Mapbox addresses and administrative areas. Lets the UI
  /// say so instead of silently looking like "no such place exists".
  final bool landmarkSourceFailed;

  bool get isEmpty => results.isEmpty;
  bool get isNotEmpty => results.isNotEmpty;

  static const LocationSearchOutcome empty = LocationSearchOutcome(results: []);
}

/// Geocoding service that merges two providers by strength:
///
/// * **Mapbox** (Geocoding v5) — addresses and administrative areas. POI data
///   was removed from v5 and lives in the Search Box API instead, so Mapbox is
///   never asked for landmarks here.
/// * **Photon** (OpenStreetMap) — the landmark/POI source, which holds local
///   places such as schools, markets, and barangay halls that Mapbox lacks.
///
/// Results are merged, deduplicated by name + proximity, and ranked by
/// text-match relevance so a specific nearby place beats a generalized
/// same-name locality. Cached in-memory to save provider quota.
class GeocodingService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      headers: const {
        'User-Agent': 'TriGo/1.0 (Flutter; tricycle ride booking)',
      },
    ),
  );

  String? get _mapboxToken {
    try {
      return dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    } catch (_) {
      // dotenv is not initialised (tests, or a failed env load): degrade to
      // Photon-only rather than throwing out of the search call.
      return null;
    }
  }

  // In-memory caches to save API quota
  static final Map<String, LocationSearchOutcome> _searchCache = {};
  static final Map<String, String> _reverseCache = {};
  static const int _maxCacheEntries = 250;

  /// Per-request result limits. Mapbox bills per request, not per result.
  static const int _mapboxRequestLimit = 10;
  static const int _photonRequestLimit = 20;

  /// How many results each provider may contribute to the merged pool. Kept
  /// separate (rather than one shared cap) so a full Mapbox page can never
  /// crowd the Photon landmarks out of the list.
  static const int _mapboxPoolLimit = 6;
  static const int _photonPoolLimit = 12;

  /// Final number of suggestions handed to the UI.
  static const int _maxResults = 12;

  /// Two results with the same normalized name closer than this are treated as
  /// the same place. Distance alone is not enough: districts such as Carbon
  /// Market hold several genuinely distinct markets within a few dozen metres.
  static const double _duplicateNameRadiusMeters = 150;

  /// Half-width in degrees of the fallback fence drawn around a point (~33 km)
  /// when no explicit service-area bounds are supplied.
  static const double _defaultHalfDegrees = 0.3;

  /// Searches for places matching [query].
  ///
  /// [proximityLat]/[proximityLng] bias and rank results by distance;
  /// [bounds] fences both providers to the caller's area (for example the
  /// TriGo service area), which keeps same-name places elsewhere out even when
  /// the user's location is unknown.
  Future<LocationSearchOutcome> search(
    String query, {
    double? proximityLat,
    double? proximityLng,
    GeoBounds? bounds,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 3) {
      return LocationSearchOutcome.empty;
    }

    final fence = resolveBounds(
      proximityLat: proximityLat,
      proximityLng: proximityLng,
      bounds: bounds,
    );

    final cacheKey = [
      trimmed.toLowerCase(),
      proximityLat?.toStringAsFixed(2) ?? '',
      proximityLng?.toStringAsFixed(2) ?? '',
      fence?.queryValue ?? '',
    ].join('_');

    // 1. Check in-memory search cache
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    // 2. Query both providers in parallel; wall time is the slower of the two.
    final fetched = await Future.wait([
      _searchMapbox(
        trimmed,
        proximityLat: proximityLat,
        proximityLng: proximityLng,
        bounds: fence,
      ),
      _searchPhoton(
        trimmed,
        proximityLat: proximityLat,
        proximityLng: proximityLng,
        bounds: fence,
      ),
    ]);

    final mapboxHits = fetched[0];
    final photonHits = fetched[1];

    // 3. Merge with independent per-provider quotas so neither starves the other.
    final merged = <LocationSearchResult>[
      ...mapboxHits.results.take(_mapboxPoolLimit),
      ...photonHits.results.take(_photonPoolLimit),
    ];

    // 4. Drop true duplicates (same name, same spot), then rank by relevance.
    final deduped = dedupeResults(merged);
    final ranked = rankResults(
      trimmed,
      deduped,
      proximityLat: proximityLat,
      proximityLng: proximityLng,
    );

    final outcome = LocationSearchOutcome(
      results: List.unmodifiable(ranked.take(_maxResults)),
      landmarkSourceFailed: photonHits.failed,
    );

    // Cache the resolved outcome
    if (outcome.isNotEmpty) {
      if (_searchCache.length >= _maxCacheEntries) {
        _searchCache.remove(_searchCache.keys.first);
      }
      _searchCache[cacheKey] = outcome;
    }

    return outcome;
  }

  /// Fence resolution: an explicit service-area box wins, otherwise fall back
  /// to a square around the user, otherwise no fence at all.
  static GeoBounds? resolveBounds({
    double? proximityLat,
    double? proximityLng,
    GeoBounds? bounds,
  }) {
    final hasProximity = proximityLat != null && proximityLng != null;
    if (bounds != null && bounds.isValid) {
      return hasProximity
          ? bounds.padToInclude(proximityLat, proximityLng)
          : bounds;
    }
    if (hasProximity) {
      return GeoBounds.fromCenter(
        proximityLat,
        proximityLng,
        halfDegrees: _defaultHalfDegrees,
      );
    }
    return null;
  }

  /// Text-match relevance of [result] for [query]; lower is better.
  ///
  /// Exact title beats "title contains the whole query", which beats all query
  /// words present in the title, which beats all words present anywhere. POIs
  /// are promoted one tier so a specific landmark wins over a generalized
  /// locality carrying a similar name.
  static int relevanceTier(String query, LocationSearchResult result) {
    final queryLower = query.trim().toLowerCase();
    final title = result.title.toLowerCase().trim();
    final haystack = '${result.title} ${result.subtitle}'.toLowerCase();
    final words = queryLower
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toList();

    int tier;
    if (title == queryLower) {
      tier = 0;
    } else if (queryLower.isNotEmpty && title.contains(queryLower)) {
      tier = 1;
    } else if (words.isNotEmpty && words.every(title.contains)) {
      tier = 2;
    } else if (words.isNotEmpty && words.every(haystack.contains)) {
      tier = 3;
    } else {
      tier = 4;
    }

    if (result.category.isPoi) tier -= 1;
    return tier;
  }

  /// Orders [results] by relevance, then specificity, then distance.
  ///
  /// Ranking is applied whether or not the user's location is known; distance
  /// only breaks ties, so a provider returning prominence-ordered rows can
  /// never push a matching landmark below an unrelated locality.
  static List<LocationSearchResult> rankResults(
    String query,
    List<LocationSearchResult> results, {
    double? proximityLat,
    double? proximityLng,
  }) {
    final hasProximity = proximityLat != null && proximityLng != null;
    final indexed = [
      for (var index = 0; index < results.length; index++)
        (result: results[index], index: index),
    ];

    indexed.sort((a, b) {
      final tier = relevanceTier(query, a.result)
          .compareTo(relevanceTier(query, b.result));
      if (tier != 0) return tier;

      // Same relevance: the specific place beats the administrative area.
      final specificity =
          (a.result.category.isPoi ? 0 : 1).compareTo(b.result.category.isPoi ? 0 : 1);
      if (specificity != 0) return specificity;

      if (hasProximity) {
        final distanceA = distanceMeters(
            proximityLat, proximityLng, a.result.latitude, a.result.longitude);
        final distanceB = distanceMeters(
            proximityLat, proximityLng, b.result.latitude, b.result.longitude);
        final distance = distanceA.compareTo(distanceB);
        if (distance != 0) return distance;
      }

      // Otherwise keep provider order (Mapbox relevance, then Photon).
      return a.index.compareTo(b.index);
    });

    return [for (final entry in indexed) entry.result];
  }

  /// Removes entries describing the same place: identical normalized name
  /// within [_duplicateNameRadiusMeters]. When two records collide, the one
  /// with the richer (longer) address detail is kept.
  static List<LocationSearchResult> dedupeResults(
    List<LocationSearchResult> results, {
    double radiusMeters = _duplicateNameRadiusMeters,
  }) {
    final kept = <LocationSearchResult>[];

    for (final candidate in results) {
      final candidateName = _normalizeName(candidate.title);
      if (candidateName.isEmpty) {
        kept.add(candidate);
        continue;
      }

      final duplicateIndex = kept.indexWhere((existing) {
        if (_normalizeName(existing.title) != candidateName) return false;
        return distanceMeters(
              existing.latitude,
              existing.longitude,
              candidate.latitude,
              candidate.longitude,
            ) <
            radiusMeters;
      });

      if (duplicateIndex == -1) {
        kept.add(candidate);
      } else if (candidate.subtitle.length >
          kept[duplicateIndex].subtitle.length) {
        kept[duplicateIndex] = candidate;
      }
    }

    return kept;
  }

  static String _normalizeName(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Mapbox feature types → display category.
  static PlaceCategory mapboxCategory(Object? placeTypes) {
    final types = placeTypes is List
        ? placeTypes.map((type) => type.toString().toLowerCase()).toList()
        : const <String>[];

    if (types.contains('address') || types.contains('secondary_address')) {
      return PlaceCategory.address;
    }
    if (types.contains('neighborhood')) return PlaceCategory.neighborhood;
    if (types.contains('locality')) return PlaceCategory.locality;
    if (types.contains('place')) return PlaceCategory.place;
    if (types.contains('region')) return PlaceCategory.region;
    if (types.contains('postcode') || types.contains('district')) {
      return PlaceCategory.locality;
    }
    return PlaceCategory.unknown;
  }

  /// Photon `osm_key`/`osm_value` → display category.
  static PlaceCategory photonCategory(Map<String, dynamic> props) {
    final key = (props['osm_key'] ?? '').toString().toLowerCase();
    final value = (props['osm_value'] ?? '').toString().toLowerCase();

    switch (key) {
      case 'amenity':
        switch (value) {
          case 'school':
          case 'college':
          case 'university':
          case 'kindergarten':
          case 'library':
            return PlaceCategory.school;
          case 'hospital':
          case 'clinic':
          case 'doctors':
          case 'dentist':
          case 'pharmacy':
            return PlaceCategory.hospital;
          case 'marketplace':
            return PlaceCategory.market;
          case 'place_of_worship':
            return PlaceCategory.worship;
          case 'townhall':
          case 'police':
          case 'fire_station':
          case 'post_office':
          case 'courthouse':
          case 'embassy':
          case 'community_centre':
            return PlaceCategory.government;
          case 'bus_station':
          case 'ferry_terminal':
          case 'taxi':
          case 'parking':
          case 'fuel':
            return PlaceCategory.transit;
          case 'restaurant':
          case 'cafe':
          case 'fast_food':
          case 'food_court':
          case 'bar':
          case 'pub':
            return PlaceCategory.food;
          case 'bank':
          case 'atm':
          case 'bureau_de_change':
            return PlaceCategory.shop;
          default:
            return PlaceCategory.landmark;
        }
      case 'shop':
        return PlaceCategory.shop;
      case 'tourism':
        switch (value) {
          case 'hotel':
          case 'hostel':
          case 'guest_house':
          case 'motel':
            return PlaceCategory.lodging;
          default:
            return PlaceCategory.landmark;
        }
      case 'historic':
        return PlaceCategory.landmark;
      case 'leisure':
        switch (value) {
          case 'park':
          case 'garden':
          case 'playground':
          case 'sports_centre':
          case 'stadium':
          case 'pitch':
            return PlaceCategory.park;
          default:
            return PlaceCategory.landmark;
        }
      case 'office':
        return value == 'government'
            ? PlaceCategory.government
            : PlaceCategory.landmark;
      case 'highway':
        return value == 'bus_stop' ? PlaceCategory.transit : PlaceCategory.street;
      case 'railway':
      case 'aeroway':
        return PlaceCategory.transit;
      case 'place':
        switch (value) {
          case 'city':
          case 'town':
          case 'village':
          case 'municipality':
          case 'hamlet':
            return PlaceCategory.place;
          case 'suburb':
          case 'neighbourhood':
          case 'quarter':
          case 'borough':
            return PlaceCategory.neighborhood;
          default:
            return PlaceCategory.locality;
        }
      case 'boundary':
      case 'admin':
        return PlaceCategory.locality;
      case 'landuse':
      case 'natural':
        return PlaceCategory.landmark;
      default:
        return PlaceCategory.unknown;
    }
  }

  /// Address detail for a Photon hit: street, barangay/district, city, region,
  /// country — in that order, without repeating the title or any part twice.
  static String photonSubtitle(
    Map<String, dynamic> props, {
    required String title,
  }) {
    final parts = <String>[];

    void add(Object? raw) {
      final value = (raw ?? '').toString().trim();
      if (value.isEmpty) return;
      if (value.toLowerCase() == title.toLowerCase()) return;
      if (parts.any((part) => part.toLowerCase() == value.toLowerCase())) {
        return;
      }
      parts.add(value);
    }

    final street = (props['street'] ?? '').toString().trim();
    final houseNumber = (props['housenumber'] ?? '').toString().trim();
    if (street.isNotEmpty) {
      add(houseNumber.isEmpty ? street : '$houseNumber $street');
    }
    add(props['locality']);
    add(props['district']);
    add(props['city'] ?? props['county']);
    add(props['state']);
    add(props['country']);

    return parts.join(', ');
  }

  /// Converts one Photon GeoJSON feature into a result, or null when it is not
  /// a usable Philippine place.
  static LocationSearchResult? photonResultFromFeature(
    Map<String, dynamic> feature,
    String query,
  ) {
    final props = feature['properties'] as Map<String, dynamic>? ?? const {};
    // Photon is worldwide; keep Philippine hits only.
    if ((props['countrycode'] ?? '').toString().toUpperCase() != 'PH') {
      return null;
    }

    final geometry = feature['geometry'] as Map<String, dynamic>? ?? const {};
    final coordinates = geometry['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) return null;

    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();

    final name = (props['name'] ?? '').toString().trim();
    final street = (props['street'] ?? '').toString().trim();
    final houseNumber = (props['housenumber'] ?? '').toString().trim();

    final String title;
    if (name.isNotEmpty) {
      title = name;
    } else if (street.isNotEmpty) {
      title = houseNumber.isEmpty ? street : '$houseNumber $street';
    } else {
      title = query;
    }

    return LocationSearchResult(
      title: title,
      subtitle: photonSubtitle(props, title: title),
      latitude: latitude,
      longitude: longitude,
      category: photonCategory(props),
      source: 'photon',
    );
  }

  /// Mapbox forward geocoding: addresses and administrative areas.
  Future<_ProviderResult> _searchMapbox(
    String query, {
    double? proximityLat,
    double? proximityLng,
    GeoBounds? bounds,
  }) async {
    const failed = _ProviderResult(results: [], failed: false);
    final token = _mapboxToken;
    if (token == null || token.isEmpty) return failed;

    try {
      final params = <String>[
        'access_token=$token',
        'country=PH',
        // Geocoding v5 no longer serves POI data (that moved to the Search Box
        // API), so these are the address/administrative types that remain.
        'types=address,neighborhood,locality,place',
        'limit=$_mapboxRequestLimit',
      ];
      if (proximityLat != null && proximityLng != null) {
        params.add('proximity=$proximityLng,$proximityLat');
      }
      if (bounds != null && bounds.isValid) {
        params.add('bbox=${bounds.queryValue}');
      }

      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json?${params.join('&')}';

      final response = await _dio.get(url);
      if (response.statusCode != 200 || response.data == null) return failed;

      final features = response.data['features'] as List<dynamic>? ?? const [];
      final results = <LocationSearchResult>[];

      for (final feature in features) {
        if (feature is! Map) continue;
        final text = (feature['text'] ?? '').toString();
        final placeName = (feature['place_name'] ?? '').toString();
        final center = feature['center'] as List<dynamic>?;
        if (center == null || center.length < 2) continue;

        final longitude = (center[0] as num).toDouble();
        final latitude = (center[1] as num).toDouble();
        final subtitle = placeName.startsWith(text)
            ? placeName
                .substring(text.length)
                .replaceFirst(RegExp(r'^,\s*'), '')
            : placeName;

        results.add(LocationSearchResult(
          title: text.isNotEmpty ? text : placeName,
          subtitle: subtitle,
          latitude: latitude,
          longitude: longitude,
          category: mapboxCategory(feature['place_type']),
          source: 'mapbox',
        ));
      }

      return _ProviderResult(results: results, failed: false);
    } catch (_) {
      // A failed address provider simply contributes nothing to the merge; it
      // is not the landmark source, so it does not degrade the outcome.
      return failed;
    }
  }

  /// Photon (OSM) search: the landmark/POI source.
  Future<_ProviderResult> _searchPhoton(
    String query, {
    double? proximityLat,
    double? proximityLng,
    GeoBounds? bounds,
  }) async {
    try {
      final params = <String>[
        'q=${Uri.encodeComponent(query)}',
        'limit=$_photonRequestLimit',
        // Server-side country filter; the parser re-checks as a backstop.
        'countrycode=PH',
      ];
      if (proximityLat != null && proximityLng != null) {
        params.add('lat=$proximityLat');
        params.add('lon=$proximityLng');
        // Tighter focus than the default zoom 12 + scale 0.4, so a nearby
        // landmark outranks a prominent place further away.
        params.add('zoom=14');
        params.add('location_bias_scale=0.2');
      }
      if (bounds != null && bounds.isValid) {
        params.add('bbox=${bounds.queryValue}');
      }

      final url = 'https://photon.komoot.io/api/?${params.join('&')}';
      final response = await _getWithRetry(url);
      if (response.statusCode != 200 || response.data == null) {
        return const _ProviderResult(results: [], failed: true);
      }

      final features = response.data['features'] as List<dynamic>? ?? const [];
      final results = <LocationSearchResult>[];

      for (final feature in features) {
        if (feature is! Map) continue;
        final parsed = photonResultFromFeature(
          Map<String, dynamic>.from(feature),
          query,
        );
        if (parsed != null) results.add(parsed);
      }

      return _ProviderResult(results: results, failed: false);
    } catch (_) {
      // Reported so the UI can say the landmark source is unavailable rather
      // than presenting a Mapbox-only list as if it were complete.
      return const _ProviderResult(results: [], failed: true);
    }
  }

  /// Single retry: a transient timeout on the public Photon server used to
  /// silently degrade the whole suggestion list to addresses only.
  Future<Response<dynamic>> _getWithRetry(String url, {int attempts = 2}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await _dio.get(url);
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError!;
  }

  /// Haversine distance in meters between two coordinates.
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    const toRadians = math.pi / 180.0;
    final dLat = (lat2 - lat1) * toRadians;
    final dLng = (lng2 - lng1) * toRadians;
    final aLat1 = lat1 * toRadians;
    final aLat2 = lat2 * toRadians;
    final h = (1 - math.cos(dLat)) / 2 +
        math.cos(aLat1) * math.cos(aLat2) * (1 - math.cos(dLng)) / 2;
    return 2 * earthRadiusMeters * math.asin(math.sqrt(h).clamp(0.0, 1.0));
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
            'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=$token&country=PH&types=address,neighborhood,locality,place';
        final response = await _dio.get(url);
        if (response.statusCode == 200 && response.data != null) {
          final features = response.data['features'] as List<dynamic>? ?? [];
          if (features.isNotEmpty) {
            final first = features.first;
            if (first is Map) {
              final address =
                  (first['place_name'] ?? first['text'] ?? '').toString();
              if (address.isNotEmpty) {
                if (_reverseCache.length >= _maxCacheEntries) {
                  _reverseCache.remove(_reverseCache.keys.first);
                }
                _reverseCache[cacheKey] = address;
                return address;
              }
            }
          }
        }
      } catch (_) {}
    }

    final fallback = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    return fallback;
  }
}

/// One provider's contribution to a merge, plus whether it failed.
class _ProviderResult {
  const _ProviderResult({required this.results, required this.failed});

  final List<LocationSearchResult> results;
  final bool failed;
}
