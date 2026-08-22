// Run-once generator for TriGo brand imagery.
//
// Renders the bundled MaterialIcons `electric_rickshaw` glyph into real PNGs
// so no external design tools or network fetches are required:
//
//   flutter test tool/generate_app_icon_test.dart
//
// Outputs (all 1024x1024 unless noted):
//   assets/icon/app_icon.png            legacy launcher icon (solid blue)
//   assets/icon/app_icon_foreground.png adaptive-icon foreground (transparent)
//   assets/icon/launch_image_ios.png    iOS splash (white + rounded tile)
//   assets/icon/launch_image_android.png Android splash tile (transparent bg)

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Color _trigoBlue = Color(0xFF2563EB);
const double _canvasSize = 1024;

bool _fontLoaded = false;

/// Widget tests do not bundle app fonts; without this the icon renders as a
/// "tofu" placeholder box. Loads the real MaterialIcons font first from the
/// asset bundle, then from the Flutter SDK cache as a fallback.
Future<void> _loadMaterialIconFont() async {
  if (_fontLoaded) return;

  Future<ByteData> readFile(String path) async {
    final bytes = File(path).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  try {
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
    _fontLoaded = true;
    return;
  } catch (_) {
    // Asset route unavailable — fall through to the SDK cache below.
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError(
        'Could not locate MaterialIcons font (no FLUTTER_ROOT set)');
  }
  final candidates = [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(readFile(path));
      await loader.load();
      _fontLoaded = true;
      return;
    }
  }
  throw StateError('MaterialIcons font not found in Flutter SDK cache');
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generates TriGo brand icons', (WidgetTester tester) async {
    tester.view.physicalSize =
        const Size(_canvasSize, _canvasSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Directory('assets/icon').createSync(recursive: true);

    await tester.runAsync(() async {
      await _loadMaterialIconFont();

      // 1. Legacy / master launcher icon: solid blue + white glyph
      await _render(
        tester,
        Container(
          width: _canvasSize,
          height: _canvasSize,
          color: _trigoBlue,
          alignment: Alignment.center,
          child: const Icon(
            Icons.electric_rickshaw,
            size: _canvasSize * 0.55,
            color: Colors.white,
          ),
        ),
        'assets/icon/app_icon.png',
      );

      // 2. Adaptive-icon foreground: transparent + glyph inside safe zone
      await _render(
        tester,
        const SizedBox(
          width: _canvasSize,
          height: _canvasSize,
          child: Center(
            child: Icon(
              Icons.electric_rickshaw,
              size: _canvasSize * 0.54,
              color: Colors.white,
            ),
          ),
        ),
        'assets/icon/app_icon_foreground.png',
      );

      // 3. iOS splash: rounded blue tile, rendered per-density for
      //    LaunchImage.imageset (storyboard centers it on white)
      final launchSizes = <String, double>{
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png': 220,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png': 440,
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png': 660,
      };
      for (final entry in launchSizes.entries) {
        await _renderLaunchTile(tester, entry.value, entry.key);
      }
      // Master copy kept under assets/icon/ for reference
      await _renderLaunchTile(
          tester, 1024, 'assets/icon/launch_image_ios_tile.png');

      // 4. Android splash tile: rounded tile on transparent (nodpi drawable)
      await _render(
        tester,
        const SizedBox(
          width: _canvasSize,
          height: _canvasSize,
          child: Center(
            child: SizedBox(
              width: 512,
              height: 512,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _trigoBlue,
                  borderRadius: BorderRadius.all(Radius.circular(122)),
                ),
                child: Center(
                  child: Icon(
                    Icons.electric_rickshaw,
                    size: 312,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        'assets/icon/launch_image_android.png',
      );
    });

    for (final name in [
      'app_icon.png',
      'app_icon_foreground.png',
      'launch_image_ios_tile.png',
      'launch_image_android.png',
    ]) {
      final f = File('assets/icon/$name');
      expect(f.existsSync(), isTrue, reason: '$name was not written');
      // A blank render compresses tiny; a real glyph render does not.
      expect(f.lengthSync(), greaterThan(5000),
          reason: '$name looks blank (font failed to render?)');
    }
  });
}

/// Rounded brand tile filling a [dim]x[dim] transparent canvas — used for
/// splash screens (iOS LaunchImage densities + Android nodpi drawable).
Future<void> _renderLaunchTile(
  WidgetTester tester,
  double dim,
  String outPath,
) async {
  await _render(
    tester,
    SizedBox(
      width: dim,
      height: dim,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _trigoBlue,
          borderRadius: BorderRadius.circular(dim * 0.238),
        ),
        child: Center(
          child: Icon(
            Icons.electric_rickshaw,
            size: dim * 0.61,
            color: Colors.white,
          ),
        ),
      ),
    ),
    outPath,
  );
}

Future<void> _render(
  WidgetTester tester,
  Widget child,
  String outPath,
) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(
            size: Size(_canvasSize, _canvasSize)),
        child: RepaintBoundary(key: key, child: child),
      ),
    ),
  );
  // Give the icon font a frame to load/rasterize.
  await tester.pump(const Duration(milliseconds: 100));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  File(outPath).writeAsBytesSync(byteData!.buffer.asUint8List());
}
