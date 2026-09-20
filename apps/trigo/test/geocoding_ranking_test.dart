import 'package:flutter_test/flutter_test.dart';
import 'package:turf/turf.dart';
import 'package:trigo/shared/services/geocoding_service.dart';
import 'package:trigo/shared/utils/geo_bounds.dart';

/// Regression fixtures taken from live provider responses for
/// "day-as elementary". Mapbox (addresses/administrative areas only) returns
/// two generalized "Day-as" barangays; Photon returns the actual school as its
/// top hit. The school must always rank first.
const _school = LocationSearchResult(
  title: 'Day-as Elementary School',
  subtitle:
      'Victorio Pacaldo, Sr. Street, Bantayan, Day-as, Cordova, Cebu, Philippines',
  latitude: 10.2545079,
  longitude: 123.94416,
  category: PlaceCategory.school,
  source: 'photon',
);

const _cordovaBarangay = LocationSearchResult(
  title: 'Day-as',
  subtitle: 'Cordova, Cebu, Philippines',
  latitude: 10.2548653,
  longitude: 123.9377525,
  category: PlaceCategory.neighborhood,
  source: 'mapbox',
);

const _cebuCityBarangay = LocationSearchResult(
  title: 'Day-as',
  subtitle: 'Cebu City, Philippines',
  latitude: 10.3014515,
  longitude: 123.9022529,
  category: PlaceCategory.neighborhood,
  source: 'mapbox',
);

Map<String, dynamic> _photonFeature(
  Map<String, dynamic> properties, {
  List<double> coordinates = const [123.9, 10.3],
}) {
  return {
    'type': 'Feature',
    'properties': properties,
    'geometry': {'type': 'Point', 'coordinates': coordinates},
  };
}

void main() {
  group('rankResults', () {
    test('specific landmark outranks generalized same-name localities', () {
      final ranked = GeocodingService.rankResults(
        'day-as elementary',
        [_cordovaBarangay, _cebuCityBarangay, _school],
      );

      expect(ranked.first.title, 'Day-as Elementary School');
    });

    test('ranks without a location fix, not only when proximity is known', () {
      final ranked = GeocodingService.rankResults(
        'day-as elementary',
        [_cordovaBarangay, _cebuCityBarangay, _school],
        proximityLat: 10.3157,
        proximityLng: 123.8854,
      );

      expect(ranked.first.title, 'Day-as Elementary School');
    });

    test('prefers the specific place when relevance ties', () {
      // "day-as" matches the barangay title exactly, and the school by
      // substring; the POI promotion must let the school win the tie.
      final ranked = GeocodingService.rankResults(
        'day-as',
        [_cordovaBarangay, _school],
      );

      expect(ranked.first.title, 'Day-as Elementary School');
    });

    test('uses distance only as a tie-break', () {
      const near = LocationSearchResult(
        title: 'Carbon Unit 1 Public Market',
        subtitle: 'M.L. Quezon Boulevard, Cebu City',
        latitude: 10.2912501,
        longitude: 123.8980227,
        category: PlaceCategory.market,
        source: 'photon',
      );
      const far = LocationSearchResult(
        title: 'Carbon Unit 3 Public Market',
        subtitle: 'M.C. Briones Street, Cebu City',
        latitude: 10.2917157,
        longitude: 123.8998404,
        category: PlaceCategory.market,
        source: 'photon',
      );

      final ranked = GeocodingService.rankResults(
        'carbon market',
        [far, near],
        proximityLat: 10.2912,
        proximityLng: 123.8980,
      );

      expect(ranked.first.title, 'Carbon Unit 1 Public Market');
    });
  });

  group('dedupeResults', () {
    test('collapses the same place from both providers, keeping the richer row',
        () {
      const sparse = LocationSearchResult(
        title: 'Day-as Barangay Hall',
        subtitle: 'Cebu City',
        latitude: 10.3017786,
        longitude: 123.9020716,
        category: PlaceCategory.government,
        source: 'mapbox',
      );
      const detailed = LocationSearchResult(
        title: 'Day-as Barangay Hall',
        subtitle: 'Imus Avenue, Day-as, Cebu City, Central Visayas, Philippines',
        latitude: 10.3017800,
        longitude: 123.9020700,
        category: PlaceCategory.government,
        source: 'photon',
      );

      final deduped = GeocodingService.dedupeResults([sparse, detailed]);

      expect(deduped, hasLength(1));
      expect(deduped.single.subtitle, contains('Imus Avenue'));
    });

    test('keeps distinct places that share a name but are far apart', () {
      const cebu = LocationSearchResult(
        title: 'Day-as',
        subtitle: 'Cebu City, Philippines',
        latitude: 10.3014515,
        longitude: 123.9022529,
        category: PlaceCategory.neighborhood,
        source: 'mapbox',
      );
      const cordova = LocationSearchResult(
        title: 'Day-as',
        subtitle: 'Cordova, Cebu, Philippines',
        latitude: 10.2548653,
        longitude: 123.9377525,
        category: PlaceCategory.neighborhood,
        source: 'mapbox',
      );

      expect(GeocodingService.dedupeResults([cebu, cordova]), hasLength(2));
    });

    test('keeps genuinely distinct neighbouring markets', () {
      const markets = [
        LocationSearchResult(
          title: 'Carbon Main Public Market',
          subtitle: 'M.C. Briones Street, Cebu City',
          latitude: 10.2920377,
          longitude: 123.8978143,
          category: PlaceCategory.market,
          source: 'photon',
        ),
        LocationSearchResult(
          title: 'Carbon Unit 1 Public Market',
          subtitle: 'M.L. Quezon Boulevard, Cebu City',
          latitude: 10.2912501,
          longitude: 123.8980227,
          category: PlaceCategory.market,
          source: 'photon',
        ),
        LocationSearchResult(
          title: 'Carbon Interim Public Market',
          subtitle: 'M.C. Briones Street, Cebu City',
          latitude: 10.2914333,
          longitude: 123.8990096,
          category: PlaceCategory.market,
          source: 'photon',
        ),
      ];

      // All three sit within ~150 m of each other; distance alone must not
      // merge them.
      expect(GeocodingService.dedupeResults(markets), hasLength(3));
    });
  });

  group('photonResultFromFeature', () {
    test('builds a landmark with its street and barangay detail', () {
      final result = GeocodingService.photonResultFromFeature(
        _photonFeature({
          'osm_key': 'amenity',
          'osm_value': 'school',
          'type': 'house',
          'name': 'Day-as Elementary School',
          'street': 'Victorio Pacaldo, Sr. Street',
          'locality': 'Bantayan',
          'district': 'Day-as',
          'city': 'Cordova',
          'state': 'Cebu',
          'country': 'Philippines',
          'postcode': '6017',
          'countrycode': 'PH',
        }, coordinates: [123.94416, 10.2545079]),
        'day-as elementary',
      );

      expect(result, isNotNull);
      expect(result!.title, 'Day-as Elementary School');
      expect(result.subtitle, contains('Victorio Pacaldo, Sr. Street'));
      expect(result.subtitle, contains('Cordova'));
      expect(result.subtitle, contains('Philippines'));
      expect(result.category, PlaceCategory.school);
      expect(result.category.isPoi, isTrue);
      expect(result.source, 'photon');
      expect(result.latitude, closeTo(10.2545079, 1e-6));
      expect(result.longitude, closeTo(123.94416, 1e-6));
    });

    test('does not repeat the title inside the subtitle', () {
      final result = GeocodingService.photonResultFromFeature(
        _photonFeature({
          'name': 'Carbon Main Public Market',
          'street': 'Carbon Main Public Market',
          'city': 'Cebu City',
          'country': 'Philippines',
          'countrycode': 'PH',
          'osm_key': 'landuse',
          'osm_value': 'construction',
        }),
        'carbon market',
      );

      expect(result!.subtitle, 'Cebu City, Philippines');
    });

    test('falls back to the street when the place has no name', () {
      final result = GeocodingService.photonResultFromFeature(
        _photonFeature({
          'housenumber': '12',
          'street': 'M.C. Briones Street',
          'city': 'Cebu City',
          'countrycode': 'PH',
          'osm_key': 'highway',
          'osm_value': 'residential',
        }),
        'm.c. briones',
      );

      expect(result!.title, '12 M.C. Briones Street');
      expect(result.subtitle, 'Cebu City');
      expect(result.category, PlaceCategory.street);
    });

    test('drops non-Philippine hits', () {
      final result = GeocodingService.photonResultFromFeature(
        _photonFeature({
          'name': 'Elementary Day Treatment at Ashcroft',
          'city': 'Redford Charter Township',
          'countrycode': 'US',
          'osm_key': 'amenity',
          'osm_value': 'school',
        }),
        'day-as elementary',
      );

      expect(result, isNull);
    });

    test('ignores features without coordinates', () {
      final result = GeocodingService.photonResultFromFeature(
        {
          'type': 'Feature',
          'properties': {'name': 'Nowhere', 'countrycode': 'PH'},
          'geometry': {'type': 'Point', 'coordinates': <double>[]},
        },
        'nowhere',
      );

      expect(result, isNull);
    });
  });

  group('category mapping', () {
    test('maps Photon osm tags to display categories', () {
      PlaceCategory categoryOf(String key, String value) =>
          GeocodingService.photonCategory({'osm_key': key, 'osm_value': value});

      expect(categoryOf('amenity', 'school'), PlaceCategory.school);
      expect(categoryOf('amenity', 'marketplace'), PlaceCategory.market);
      expect(categoryOf('amenity', 'place_of_worship'), PlaceCategory.worship);
      expect(categoryOf('amenity', 'townhall'), PlaceCategory.government);
      expect(categoryOf('highway', 'bus_stop'), PlaceCategory.transit);
      expect(categoryOf('shop', 'supermarket'), PlaceCategory.shop);
      expect(categoryOf('tourism', 'museum'), PlaceCategory.landmark);
      expect(categoryOf('tourism', 'hotel'), PlaceCategory.lodging);
      expect(categoryOf('leisure', 'park'), PlaceCategory.park);
      expect(categoryOf('place', 'quarter'), PlaceCategory.neighborhood);
      expect(categoryOf('place', 'city'), PlaceCategory.place);
      expect(categoryOf('landuse', 'construction'), PlaceCategory.landmark);
    });

    test('marks POI categories as specific places', () {
      expect(PlaceCategory.school.isPoi, isTrue);
      expect(PlaceCategory.market.isPoi, isTrue);
      expect(PlaceCategory.neighborhood.isPoi, isFalse);
      expect(PlaceCategory.locality.isPoi, isFalse);
      expect(PlaceCategory.address.isPoi, isFalse);
    });

    test('maps Mapbox place types to administrative categories', () {
      expect(GeocodingService.mapboxCategory(['neighborhood']),
          PlaceCategory.neighborhood);
      expect(GeocodingService.mapboxCategory(['locality']),
          PlaceCategory.locality);
      expect(GeocodingService.mapboxCategory(['place']), PlaceCategory.place);
      expect(GeocodingService.mapboxCategory(['address']),
          PlaceCategory.address);
      // Geocoding v5 no longer serves POIs, so a "poi" type must not be
      // mistaken for a landmark.
      expect(GeocodingService.mapboxCategory(['poi']), PlaceCategory.unknown);
    });
  });

  group('resolveBounds', () {
    const area = GeoBounds(
      minLat: 10.0,
      minLng: 123.6,
      maxLat: 10.6,
      maxLng: 124.2,
    );

    test('prefers the supplied service area', () {
      final bounds = GeocodingService.resolveBounds(
        proximityLat: 10.3157,
        proximityLng: 123.8854,
        bounds: area,
      );

      expect(bounds!.minLat, area.minLat);
      expect(bounds.maxLng, area.maxLng);
    });

    test('grows the service area so the user is never excluded', () {
      final bounds = GeocodingService.resolveBounds(
        proximityLat: 11.0,
        proximityLng: 123.8854,
        bounds: area,
      );

      expect(bounds!.contains(11.0, 123.8854), isTrue);
    });

    test('falls back to a square around the user, then to no fence', () {
      final around = GeocodingService.resolveBounds(
        proximityLat: 10.3157,
        proximityLng: 123.8854,
      );

      expect(around, isNotNull);
      expect(around!.contains(10.3157, 123.8854), isTrue);
      expect(around.maxLat - around.minLat, closeTo(0.6, 1e-9));
      expect(GeocodingService.resolveBounds(), isNull);
    });
  });

  group('GeoBounds', () {
    test('encodes the bbox value both providers expect', () {
      const bounds = GeoBounds(
        minLat: 10.1,
        minLng: 123.8,
        maxLat: 10.4,
        maxLng: 124.0,
      );

      expect(bounds.queryValue, '123.8,10.1,124.0,10.4');
    });

    test('derives a box from polygon rings', () {
      final bounds = boundsFromPolygonRings([
        [
          Position(123.9, 10.3),
          Position(124.0, 10.4),
        ],
      ]);

      expect(bounds, isNotNull);
      expect(bounds!.queryValue, '123.9,10.3,124.0,10.4');
    });

    test('returns null when rings carry no usable coordinates', () {
      expect(boundsFromPolygonRings(null), isNull);
      expect(boundsFromPolygonRings(const []), isNull);
    });
  });

  group('search input guards', () {
    test('returns an empty outcome without a network call for short queries',
        () async {
      final service = GeocodingService();

      expect((await service.search('')).isEmpty, isTrue);
      expect((await service.search('ab')).isEmpty, isTrue);
      expect((await service.search('   ')).isEmpty, isTrue);
    });
  });
}
