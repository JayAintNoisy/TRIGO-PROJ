import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trigo/core/router/branch_visibility.dart';
import 'package:trigo/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:trigo/features/ride_booking/data/rides_repository.dart';

/// Driver earnings: newest completed trip first, each row opens its details,
/// and the list refreshes when the tab is revisited.
Map<String, dynamic> _ride({
  required String id,
  required String pickup,
  required String dropoff,
  required String completedAt,
  String? createdAt,
  double fare = 50,
}) =>
    <String, dynamic>{
      'id': id,
      'status': 'completed',
      'pickupAddress': pickup,
      'dropoffAddress': dropoff,
      'fareEstimate': fare,
      'fareFinal': fare,
      'completedAt': completedAt,
      'createdAt': createdAt ?? completedAt,
    };

Future<void> _pumpEarnings(
  WidgetTester tester,
  List<dynamic> Function() rides,
) async {
  final router = GoRouter(
    initialLocation: '/driver/earnings',
    routes: [
      GoRoute(
        path: '/driver/earnings',
        builder: (context, state) => ProviderScope(
          child: EarningsScreen(
            rideLoader: ({String? status}) async => rides(),
          ),
        ),
      ),
      GoRoute(
        path: '/ride/:id/details',
        builder: (context, state) =>
            Scaffold(body: Text('details:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

/// Vertical position of a row's route text, for order assertions.
double _rowY(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  setUp(() {
    // Keeps the shared Dio client constructible if a screen falls back to its
    // real repository.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  group('RidesRepository.sortByCompletedDesc', () {
    test('orders by completion time, not booking time', () {
      // The later booking was completed first: the earnings list must show the
      // 12:00 completion above the 11:30 one even though its booking is older.
      final rides = [
        _ride(
          id: 'late-booking',
          pickup: 'A',
          dropoff: 'B',
          createdAt: '2026-01-01T11:00:00.000Z',
          completedAt: '2026-01-01T11:30:00.000Z',
        ),
        _ride(
          id: 'early-booking',
          pickup: 'C',
          dropoff: 'D',
          createdAt: '2026-01-01T09:00:00.000Z',
          completedAt: '2026-01-01T12:00:00.000Z',
        ),
      ];

      final sorted = RidesRepository.sortByCompletedDesc(rides);

      expect(sorted.first['id'], 'early-booking');
      expect(sorted.last['id'], 'late-booking');
    });

    test('falls back to creation time when a trip has not completed', () {
      final rides = [
        <String, dynamic>{'id': 'a', 'createdAt': '2026-01-01T10:00:00.000Z'},
        <String, dynamic>{'id': 'b', 'createdAt': '2026-01-01T12:00:00.000Z'},
      ];

      expect(RidesRepository.sortByCompletedDesc(rides).first['id'], 'b');
    });

    test('leaves the caller list untouched and tolerates junk', () {
      final rides = <dynamic>[
        'not a ride',
        <String, dynamic>{'id': 'a', 'completedAt': '2026-01-01T10:00:00.000Z'},
      ];
      final before = [...rides];

      final sorted = RidesRepository.sortByCompletedDesc(rides);

      expect(sorted.first['id'], 'a');
      expect(rides, equals(before), reason: 'the input list must not be sorted');
    });
  });

  group('earnings list', () {
    testWidgets('lists the most recently completed trip first',
        (tester) async {
      await _pumpEarnings(tester, () => [
            _ride(
              id: 'older',
              pickup: 'Alpha',
              dropoff: 'Beta',
              completedAt: '2026-01-01T10:00:00.000Z',
            ),
            _ride(
              id: 'newest',
              pickup: 'Gamma',
              dropoff: 'Delta',
              completedAt: '2026-01-01T13:00:00.000Z',
            ),
            _ride(
              id: 'middle',
              pickup: 'Eps',
              dropoff: 'Zeta',
              completedAt: '2026-01-01T11:00:00.000Z',
            ),
          ]);

      final newestY = _rowY(tester, 'Gamma → Delta');
      final middleY = _rowY(tester, 'Eps → Zeta');
      final olderY = _rowY(tester, 'Alpha → Beta');

      expect(newestY, lessThan(middleY));
      expect(middleY, lessThan(olderY));
    });

    testWidgets('tapping a trip opens its details', (tester) async {
      await _pumpEarnings(tester, () => [
            _ride(
              id: 'ride-42',
              pickup: 'Alpha',
              dropoff: 'Beta',
              completedAt: '2026-01-01T10:00:00.000Z',
            ),
          ]);

      await tester.tap(find.text('Alpha → Beta'));
      await tester.pumpAndSettle();

      expect(find.text('details:ride-42'), findsOneWidget);
    });

    testWidgets('reloads when the tab becomes visible again', (tester) async {
      var rides = [
        _ride(
          id: 'first',
          pickup: 'Alpha',
          dropoff: 'Beta',
          completedAt: '2026-01-01T10:00:00.000Z',
        ),
      ];
      await _pumpEarnings(tester, () => rides);

      expect(find.text('Alpha → Beta'), findsOneWidget);

      // A trip completes while the driver is on another tab.
      rides = [
        ...rides,
        _ride(
          id: 'second',
          pickup: 'Gamma',
          dropoff: 'Delta',
          completedAt: '2026-01-01T10:05:00.000Z',
        ),
      ];

      // Leaving and coming back to the middle tab must refresh the list.
      activeBranchNotifier.value = 0;
      await tester.pump();
      activeBranchNotifier.value = middleBranchIndex;
      await tester.pumpAndSettle();

      expect(find.text('Gamma → Delta'), findsOneWidget);
      // ...and the new trip is first, being the most recent completion.
      expect(
        _rowY(tester, 'Gamma → Delta'),
        lessThan(_rowY(tester, 'Alpha → Beta')),
      );
    });

    testWidgets('shows the payment method a trip was settled with',
        (tester) async {
      await _pumpEarnings(tester, () => [
            {
              ..._ride(
                id: 'paid',
                pickup: 'Alpha',
                dropoff: 'Beta',
                completedAt: '2026-01-01T10:00:00.000Z',
              ),
              'settledPaymentMethod': 'gcash',
              'paymentMethod': 'cash',
            },
            {
              ..._ride(
                id: 'unsettled',
                pickup: 'Gamma',
                dropoff: 'Delta',
                completedAt: '2026-01-01T09:00:00.000Z',
              ),
              'paymentMethod': 'maya',
            },
          ]);

      // The settled method wins over the passenger's earlier choice...
      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('Cash'), findsNothing);
      // ...and the chosen method is the fallback when nothing settled it.
      expect(find.text('Maya'), findsOneWidget);
    });

    testWidgets('shows the empty state', (tester) async {
      await _pumpEarnings(tester, () => []);

      expect(find.text('No completed trips yet'), findsOneWidget);
    });
  });
}
