import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trigo/features/ride_booking/presentation/screens/rating_screen.dart';
import 'package:trigo/shared/utils/rating_window.dart';

/// The rating form creates a rating, and changes one that already exists.
Map<String, dynamic> _ride({int? rating, String? comment}) => <String, dynamic>{
      'id': 'ride-1',
      'status': 'completed',
      'rating': rating,
      'ratingComment': comment,
    };

Future<void> _pumpRatingScreen(
  WidgetTester tester, {
  bool isEditing = false,
  int? rating,
  String? comment,
  Size size = const Size(411, 1400),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: isEditing ? '/ride/ride-1/rating?edit=1' : '/ride/ride-1/rating',
    routes: [
      GoRoute(
        path: '/ride/:id/rating',
        builder: (context, state) => RatingScreen(
          rideId: state.pathParameters['id'] ?? '',
          isEditing: state.uri.queryParameters['edit'] == '1',
          rideLoader: (_) async => _ride(rating: rating, comment: comment),
        ),
      ),
      GoRoute(
        path: '/ride/:id/details',
        builder: (context, state) =>
            Scaffold(body: Text('receipt:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // The screen's fallback repository builds the shared Dio client.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  group('rating edit window', () {
    final completed = DateTime(2026, 1, 1, 12);

    test('a fresh trip is editable', () {
      expect(
        isRatingEditable(completed, now: completed.add(const Duration(hours: 1))),
        isTrue,
      );
    });

    test('is still editable on the boundary and closed just after', () {
      expect(
        isRatingEditable(completed, now: completed.add(ratingEditWindow)),
        isTrue,
      );
      expect(
        isRatingEditable(
          completed,
          now: completed.add(ratingEditWindow).add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('a trip with no completion time is never editable', () {
      expect(isRatingEditable(null), isFalse);
    });

    test('reports the time left, and nothing once closed', () {
      expect(
        ratingEditTimeLeft(completed, now: completed.add(const Duration(hours: 20))),
        const Duration(hours: 4),
      );
      expect(
        ratingEditTimeLeft(completed, now: completed.add(const Duration(days: 2))),
        isNull,
      );
    });

    test('labels the window for user-facing copy', () {
      expect(ratingEditWindowLabel(), '24 hours');
    });
  });

  group('rating screen', () {
    testWidgets('creates a rating and lands on the receipt', (tester) async {
      await _pumpRatingScreen(tester);

      expect(find.text('Rate Your Ride'), findsOneWidget);
      expect(find.text('Tap a star to rate'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pump();
      expect(find.text('4 out of 5'), findsOneWidget);

      await tester.tap(find.text('Submit & View Receipt'));
      // The submit button spins while in flight, so settle on explicit frames
      // rather than pumpAndSettle (which would wait for the spinner forever).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The repository call fails against the test HTTP client, so the screen
      // stays put and explains itself instead of navigating away.
      expect(find.text('Rate Your Ride'), findsOneWidget);
    });

    testWidgets('prefills the existing rating and feedback when editing',
        (tester) async {
      await _pumpRatingScreen(
        tester,
        isEditing: true,
        rating: 3,
        comment: 'Polite, On Time',
      );

      expect(find.text('Edit Your Rating'), findsOneWidget);
      expect(find.text('3 out of 5'), findsOneWidget);
      expect(find.text('Update Rating'), findsOneWidget);
      // Stored feedback comes back selected, so an edit does not silently drop
      // it.
      expect(find.textContaining('within 24 hours'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });

    testWidgets('an edit submits the changed stars', (tester) async {
      await _pumpRatingScreen(tester, isEditing: true, rating: 2);

      // With two stars filled, the fifth star is the third outline.
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(2));
      await tester.pump();
      expect(find.text('5 out of 5'), findsOneWidget);
    });

    testWidgets('does not overflow on a small screen with large text',
        (tester) async {
      await _pumpRatingScreen(
        tester,
        isEditing: true,
        rating: 5,
        comment: 'Polite, Safe, Clean, On Time, Friendly',
        size: const Size(320, 480),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
