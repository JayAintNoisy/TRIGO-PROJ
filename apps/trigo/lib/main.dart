import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The .env asset is optional at build time; a missing file must not crash
  // boot. When the load fails every dotenv lookup degrades to its default.
  try {
    await dotenv.load();
  } catch (_) {
    // Continue booting with defaults (no Mapbox token, default release info).
  }
  String? mapboxToken;
  try {
    mapboxToken = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
  } catch (_) {
    mapboxToken = null;
  }
  if (mapboxToken != null && mapboxToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxToken);
  }
  MapboxMapsOptions.setTileStoreUsageMode(
      TileStoreUsageMode.READ_AND_UPDATE);
  runApp(
    const ProviderScope(
      child: TriGoApp(),
    ),
  );
}
