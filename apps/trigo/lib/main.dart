import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  final mapboxToken = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
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
