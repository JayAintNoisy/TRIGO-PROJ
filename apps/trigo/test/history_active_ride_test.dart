import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trigo/features/history/presentation/screens/history_screen.dart';
import 'package:trigo/features/ride_booking/data/rides_repository.dart';

/// Serves a fixed ride list without constructing a real repository (whose Dio
/// client would require .env to be loaded).
Future<List<dynamic>> Function() _loader(
  List<dynamic> rides, {
  Object? error,
}) =>
    () async {
      final failure = error;
      if (failure != null) throw failure;
      return rides;
    };

Map<String, dynamic> _ride({
  required String id,
  required String status,
  required String pickup,
  required String dropoff,
}) =>
    <String, dynamic>{
      'id': id,
      'status': status,
      'pickupAddress': pickup,
      'dropoffAddress': dropoff,
      'fareEstimate': 42.0,
      'createdAt': '2026-09-20T02:00:00.000Z',
    };

Future<void> _pumpHistory(
  WidgetTester tester,
  List<dynamic> rides, {
  Object? error,
}) async {
  final router = GoRouter(
    initialLocation: '/history',
    routes: [
      GoRoute(
        path: '/history',
        builder: (context, state) => ProviderScope(
          child: HistoryScreen(rideLoader: _loader(rides, error: error)),
        ),
      ),
      GoRoute(
        path: '/ride/:id/tracking',
        builder: (context, state) =>
            Scaffold(body: Text('tracking:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/ride/:id/rating',
        builder: (context, state) =>
            Scaffold(body: Text('rating:${state.pathParameters['id']}')),
      ),
    ],
  );

  // ProviderScope sits inside the route (not around MaterialApp.router) so it
  // does not nest a second uncontrolled scope in the router's context.
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(useMaterial3: true),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RidesRepository status helpers', () {
    test('treats every non-terminal status as active', () {
      expect(RidesRepository.isActiveStatus('requested'), isTrue);
      expect(RidesRepository.isActiveStatus('accepted'), isTrue);
      expect(RidesRepository.isActiveStatus('driver_arriving'), isTrue);
      expect(RidesRepository.isActiveStatus('in_progress'), isTrue);
    });

    test('treats terminal and unknown statuses as inactive', () {
      expect(RidesRepository.isActiveStatus('completed'), isFalse);
      expect(RidesRepository.isActiveStatus('cancelled'), isFalse);
      expect(RidesRepository.isActiveStatus(null), isFalse);
      expect(RidesRepository.isActiveStatus(''), isFalse);
      expect(RidesRepository.isActiveStatus('bogus'), isFalse);
    });

    test('reports a distinct label per in-flight stage', () {
      expect(
          RidesRepository.activeStatusLabel('requested'), 'Finding a driver');
      expect(
          RidesRepository.activeStatusLabel('accepted'), 'Driver on the way');
      expect(RidesRepository.activeStatusLabel('driver_arriving'),
          'Driver arriving');
      expect(
          RidesRepository.activeStatusLabel('in_progress'), 'Trip in progress');
    });

    test('falls back to a generic label for unknown statuses', () {
      expect(RidesRepository.activeStatusLabel('mystery'), 'Active');
      expect(RidesRepository.activeStatusLabel(null), 'Active');
    });
  });

  group('History rendering', () {
    testWidgets('pins the active ride with its real stage label',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(
            id: 'r1', status: 'in_progress', pickup: 'Alpha', dropoff: 'Beta'),
        _ride(id: 'r2', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
        _ride(id: 'r3', status: 'cancelled', pickup: 'Eps', dropoff: 'Zeta'),
      ]);

      expect(find.text('ACTIVE RIDE'), findsOneWidget);
      expect(find.text('Trip in progress'), findsOneWidget);
      expect(find.text('Continue ride'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('active ride is pinned once and excluded from the list',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(id: 'r1', status: 'accepted', pickup: 'Alpha', dropoff: 'Beta'),
        _ride(id: 'r2', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
      ]);

      expect(find.text('Alpha'), findsOneWidget,
          reason: 'pinned card only, not duplicated in the list');
      expect(find.text('Driver on the way'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('no active card when every ride is terminal', (tester) async {
      await _pumpHistory(tester, [
        _ride(id: 'r1', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
      ]);

      expect(find.text('ACTIVE RIDE'), findsNothing);
      expect(find.text('Continue ride'), findsNothing);
    });

    testWidgets('empty list shows the placeholder', (tester) async {
      await _pumpHistory(tester, []);
      expect(find.text('No rides yet'), findsOneWidget);
    });
  });

  group('History navigation', () {
    testWidgets('tapping Continue ride opens tracking for the active ride',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(
            id: 'r1', status: 'in_progress', pickup: 'Alpha', dropoff: 'Beta'),
      ]);

      await tester.tap(find.text('Continue ride'));
      await tester.pumpAndSettle();

      expect(find.text('tracking:r1'), findsOneWidget);
    });

    testWidgets('tapping a completed card opens rating', (tester) async {
      await _pumpHistory(tester, [
        _ride(id: 'r9', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
      ]);

      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(find.text('rating:r9'), findsOneWidget);
    });

    testWidgets('a cancelled card is inert', (tester) async {
      await _pumpHistory(tester, [
        _ride(id: 'r5', status: 'cancelled', pickup: 'Eps', dropoff: 'Zeta'),
      ]);

      await tester.tap(find.text('Eps'));
      await tester.pumpAndSettle();

      // Still on History: nothing navigated away.
      expect(find.text('Ride History'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });
  });
}
