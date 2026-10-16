import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trigo/core/router/branch_visibility.dart';
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
  String? settledPaymentMethod,
  int? rating,
}) =>
    <String, dynamic>{
      'id': id,
      'status': status,
      'pickupAddress': pickup,
      'dropoffAddress': dropoff,
      'fareEstimate': 42.0,
      'settledPaymentMethod': settledPaymentMethod,
      'rating': rating,
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
      GoRoute(
        path: '/ride/:id/details',
        builder: (context, state) =>
            Scaffold(body: Text('details:${state.pathParameters['id']}')),
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

  group('History rendering', () {    testWidgets('pins the active ride with its real stage label',
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

    testWidgets('shows how a finished trip was paid for, and its rating',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(
          id: 'r1',
          status: 'completed',
          pickup: 'Gamma',
          dropoff: 'Delta',
          settledPaymentMethod: 'gcash',
          rating: 4,
        ),
        _ride(
          id: 'r2',
          status: 'completed',
          pickup: 'Eps',
          dropoff: 'Zeta',
          settledPaymentMethod: 'cash',
        ),
      ]);

      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('4 / 5'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      // An unrated trip shows no rating chip rather than a zero.
      expect(find.text('0 / 5'), findsNothing);
    });

    testWidgets('an in-flight trip carries no payment method yet',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(
          id: 'r1',
          status: 'in_progress',
          pickup: 'Alpha',
          dropoff: 'Beta',
          settledPaymentMethod: 'cash',
        ),
      ]);

      expect(find.text('Cash'), findsNothing);
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

    testWidgets('tapping a completed card opens its trip details',
        (tester) async {
      await _pumpHistory(tester, [
        _ride(id: 'r9', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
      ]);

      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();

      expect(find.text('details:r9'), findsOneWidget);
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

  group('History freshness', () {
    testWidgets('reloads when the tab becomes visible again', (tester) async {
      // The loader closes over this list, so it is mutated rather than
      // replaced when a new ride appears.
      final rides = <dynamic>[
        _ride(id: 'r1', status: 'completed', pickup: 'Gamma', dropoff: 'Delta'),
      ];
      await _pumpHistory(tester, rides);

      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      // A ride is booked elsewhere while the tab is off screen.
      rides.add(
        _ride(id: 'r2', status: 'completed', pickup: 'Alpha', dropoff: 'Beta'),
      );

      activeBranchNotifier.value = 0;
      await tester.pump();
      activeBranchNotifier.value = middleBranchIndex;
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget,
          reason: 'a revisit must not show a stale list');
    });

    testWidgets('a failed refresh keeps the rides already on screen',
        (tester) async {
      var shouldFail = false;
      final router = GoRouter(
        initialLocation: '/history',
        routes: [
          GoRoute(
            path: '/history',
            builder: (context, state) => ProviderScope(
              child: HistoryScreen(
                rideLoader: () async {
                  if (shouldFail) throw Exception('offline');
                  return [
                    _ride(
                        id: 'r1',
                        status: 'completed',
                        pickup: 'Gamma',
                        dropoff: 'Delta'),
                  ];
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('Gamma'), findsOneWidget);

      shouldFail = true;
      activeBranchNotifier.value = 0;
      await tester.pump();
      activeBranchNotifier.value = middleBranchIndex;
      await tester.pumpAndSettle();

      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
    });
  });
}
