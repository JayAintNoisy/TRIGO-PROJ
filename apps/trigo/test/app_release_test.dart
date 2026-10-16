import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/core/constants/app_release.dart';
import 'package:trigo/shared/widgets/app_splash_screen.dart';

/// The display rule, mirrored by the landing page:
///
///   APP_RELEASE_VERSION trimmed, default `1.0.0`
///   APP_RELEASE_LABEL   optional; absent/empty/whitespace => production
///
///   production => `1.0.0`
///   labelled   => `1.0.0-demo` (label verbatim)
///
/// Note: these tests never call `dotenv.load()`, so they run with dotenv
/// uninitialised — exactly the `flutter test` situation that used to throw out
/// of a bare `dotenv.env[...]` lookup. `dotenv` is a mutable top-level, so a
/// fresh instance is installed in `setUp` to keep the groups independent of
/// execution order (`flutter test --test-randomize-ordering-seed`).
void main() {
  group('AppReleaseInfo with dotenv uninitialised', () {
    setUp(() {
      dotenv = DotEnv();
    });

    test('falls back to the production default and never throws', () {
      expect(AppReleaseInfo.isProduction, isTrue);
      expect(AppReleaseInfo.display, '1.0.0');
      expect(AppReleaseInfo.version, '1.0.0');
      expect(AppReleaseInfo.label, isEmpty);
    });
  });

  group('AppReleaseInfo.resolveDisplay', () {
    test('appends a non-blank label verbatim', () {
      expect(
        AppReleaseInfo.resolveDisplay(version: '1.0.0', label: 'demo'),
        '1.0.0-demo',
      );
    });

    test('blank label variants all mean production', () {
      expect(AppReleaseInfo.resolveDisplay(version: '1.0.0', label: ''), '1.0.0');
      expect(
        AppReleaseInfo.resolveDisplay(version: '1.0.0', label: '   '),
        '1.0.0',
      );
      expect(AppReleaseInfo.resolveDisplay(version: '1.0.0', label: null),
          '1.0.0');
    });

    test('resolves another version and label', () {
      expect(
        AppReleaseInfo.resolveDisplay(version: '2.1.0', label: 'beta'),
        '2.1.0-beta',
      );
    });

    test('missing or blank version falls back to 1.0.0', () {
      expect(AppReleaseInfo.resolveDisplay(label: 'demo'), '1.0.0-demo');
      expect(AppReleaseInfo.resolveDisplay(version: '', label: 'demo'),
          '1.0.0-demo');
      expect(AppReleaseInfo.resolveDisplay(version: '  ', label: 'demo'),
          '1.0.0-demo');
      expect(AppReleaseInfo.resolveDisplay(), '1.0.0');
    });

    test('trims surrounding whitespace and preserves arbitrary label text', () {
      expect(
        AppReleaseInfo.resolveDisplay(version: ' 3.4.5 ', label: ' QA Build '),
        '3.4.5-QA Build',
      );
      expect(
        AppReleaseInfo.resolveDisplay(version: '1.0.0', label: 'staging-x1'),
        '1.0.0-staging-x1',
      );
    });
  });

  group('AppSplashScreen', () {
    testWidgets('shows the resolved version without settling animations',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AppSplashScreen()),
      );
      // Only a plain pump: the splash hosts an infinite progress indicator, so
      // pumpAndSettle would time out.
      await tester.pump();

      expect(find.text('TriGo'), findsOneWidget);
      // The version always contains the resolved default at minimum.
      expect(find.textContaining('1.0.0'), findsOneWidget);
      expect(find.text(AppReleaseInfo.display), findsOneWidget);
    });
  });

  // Loads the environment for its own tests only, and restores the pristine
  // uninitialised global afterwards so no other group is affected.
  group('AppReleaseInfo with a labelled environment', () {
    setUp(() {
      dotenv.testLoad(
        fileInput: 'APP_RELEASE_VERSION=1.0.0\nAPP_RELEASE_LABEL=demo\n',
      );
    });

    tearDown(() {
      dotenv = DotEnv();
    });

    test('reads version and label from the environment', () {
      expect(AppReleaseInfo.version, '1.0.0');
      expect(AppReleaseInfo.label, 'demo');
      expect(AppReleaseInfo.isProduction, isFalse);
      expect(AppReleaseInfo.display, '1.0.0-demo');
    });

    testWidgets('splash renders the labelled build as an amber pill',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AppSplashScreen()),
      );
      await tester.pump();

      expect(find.text('1.0.0-demo'), findsOneWidget);

      final ancestorDecorations = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('1.0.0-demo'),
              matching: find.byType(Container),
            ),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>();
      expect(
        ancestorDecorations.any((d) => d.color == const Color(0xFFFEF3C7)),
        isTrue,
        reason: 'the splash pill should use the amber badge background',
      );

      final label = tester.widget<Text>(find.text('1.0.0-demo'));
      expect(label.style!.color, const Color(0xFF92400E));
    });
  });
}
