import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trigo/core/router/app_router.dart';
import 'package:trigo/features/auth/data/auth_repository.dart';
import 'package:trigo/features/auth/presentation/providers/auth_provider.dart';
import 'package:trigo/features/history/presentation/screens/ride_details_screen.dart';
import 'package:trigo/features/payments/data/payments_repository.dart';
import 'package:trigo/shared/widgets/app_mode_switch.dart';

/// Trip details: route, fare breakdown, the transaction behind the trip and
/// the rating the passenger gave.
Map<String, dynamic> _ride({
  String status = 'completed',
  double fareEstimate = 85,
  double? fareFinal = 90,
  double cancellationFee = 0,
  String? cancellationReason,
  String? settledPaymentMethod = 'gcash',
  int? rating,
  String? ratingComment,
  String? ratedAt,
  String? completedAt,
}) =>
    <String, dynamic>{
      'id': 'ride-abcdef12',
      'status': status,
      'pickupAddress': 'City Hall',
      'dropoffAddress': 'Public Market',
      'fareEstimate': fareEstimate,
      'fareFinal': fareFinal,
      'distanceKm': 4.25,
      'cancellationFee': cancellationFee,
      'cancellationReason': cancellationReason,
      'settledPaymentMethod': settledPaymentMethod,
      'rating': rating,
      'ratingComment': ratingComment,
      'ratedAt': ratedAt,
      'driverName': 'Juan Dela Cruz',
      'customerName': 'Maria Clara',
      'tricyclePlateNumber': 'ABC-1234',
      'createdAt': '2026-01-01T09:00:00.000Z',
      'completedAt': completedAt ?? DateTime.now().toUtc().toIso8601String(),
    };

/// A completion time safely inside the rating edit window.
String get _completedJustNow => DateTime.now().toUtc().toIso8601String();

/// A completion time comfortably past the 24-hour edit window.
String get _completedTwoDaysAgo => DateTime.now()
    .toUtc()
    .subtract(const Duration(days: 2))
    .toIso8601String();

Future<void> _pumpDetails(
  WidgetTester tester, {
  required Map<String, dynamic> ride,
  RidePayment? payment,
  Object? rideError,
  Size size = const Size(411, 1400),
  double textScale = 1.0,
  bool asDriver = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final router = GoRouter(
    initialLocation: '/ride/ride-abcdef12/details',
    routes: [
      GoRoute(
        path: '/ride/:id/details',
        builder: (context, state) => RideDetailsScreen(
          rideId: state.pathParameters['id'] ?? '',
          rideLoader: (_) async {
            if (rideError != null) throw rideError;
            return ride;
          },
          paymentLoader: (_) async => payment,
        ),
      ),
      GoRoute(
        path: '/ride/:id/rating',
        builder: (context, state) => Scaffold(
          body: Text(
            'rating:${state.pathParameters['id']}'
            '${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
          ),
        ),
      ),
      GoRoute(
        path: '/ride/:id/tracking',
        builder: (context, state) =>
            Scaffold(body: Text('tracking:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (asDriver)
          authProvider.overrideWith((ref) => _DriverAuthNotifier()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Reports the driver mode, which is what the screen branches on for wording
/// and for who may edit a rating.
class _DriverAuthNotifier extends AuthNotifier {
  _DriverAuthNotifier() : super(AuthRepository()) {
    state = const AuthState(isAuthenticated: true, activeMode: AppUserMode.driver);
    // The notifier mirrors state into the router's redirect notifier; clear it
    // so nothing leaks into another test in this file.
    addTearDown(() => authRedirectNotifier.value = null);
  }
}

void main() {
  setUp(() {
    // The screen resolves the viewer's role through authProvider, which builds
    // the shared Dio client and therefore needs the dotenv map.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  testWidgets('shows the route, fare breakdown and transaction', (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(),
      payment: RidePayment(
        id: 'pay-1',
        rideId: 'ride-abcdef12',
        amount: 90,
        method: 'gcash',
        status: 'completed',
        createdAt: DateTime(2026, 1, 1, 9, 36),
      ),
    );

    expect(find.text('Trip Details'), findsOneWidget);
    expect(find.text('Trip #ride-abc'), findsOneWidget);
    expect(find.text('City Hall'), findsOneWidget);
    expect(find.text('Public Market'), findsOneWidget);

    // Fare breakdown
    expect(find.text('Estimated fare'), findsOneWidget);
    expect(find.text('Final fare'), findsOneWidget);
    expect(find.text('\u20B190.00'), findsWidgets);
    expect(find.text('4.25 km'), findsOneWidget);

    // Transaction
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('GCash'), findsOneWidget);
    expect(find.textContaining('Paid'), findsOneWidget);
    // A passenger sees their driver, not themselves.
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('ABC-1234'), findsOneWidget);
  });

  testWidgets('explains a trip with no transaction yet', (tester) async {
    await _pumpDetails(tester, ride: _ride(status: 'in_progress'), payment: null);

    expect(
      find.text('A transaction is recorded when the trip is completed.'),
      findsOneWidget,
    );
    expect(find.text('Track this ride'), findsOneWidget);
  });

  testWidgets('shows the cancellation fee on a cancelled trip', (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(
        status: 'cancelled',
        fareFinal: null,
        cancellationFee: 30,
        cancellationReason: 'Cancelled by customer',
      ),
      payment: null,
    );

    expect(find.text('Cancellation fee'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.textContaining('Cancelled by customer'), findsOneWidget);
  });

  testWidgets('offers the passenger a rating action when unrated',
      (tester) async {
    await _pumpDetails(tester, ride: _ride(rating: null), payment: null);

    expect(find.text('You have not rated this trip yet.'), findsOneWidget);
    await tester.tap(find.text('Rate your driver'));
    await tester.pumpAndSettle();

    expect(find.text('rating:ride-abcdef12'), findsOneWidget);
  });

  testWidgets('shows a stored rating instead of asking again', (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(
        rating: 4,
        ratingComment: 'Polite, Safe',
        ratedAt: _completedJustNow,
      ),
      payment: null,
    );

    expect(find.text('Your rating'), findsOneWidget);
    expect(find.text('4 out of 5'), findsOneWidget);
    expect(find.text('Polite, Safe'), findsOneWidget);
    // Nothing asks for the rating a second time.
    expect(find.text('Rate your driver'), findsNothing);
    expect(find.text('You have not rated this trip yet.'), findsNothing);
  });

  testWidgets('lets the passenger edit a rating inside the window',
      (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(
        rating: 3,
        ratedAt: _completedJustNow,
        completedAt: _completedJustNow,
      ),
      payment: null,
    );

    expect(find.text('Tap to change your rating'), findsOneWidget);

    await tester.tap(find.text('Tap to change your rating'));
    await tester.pumpAndSettle();

    expect(find.text('rating:ride-abcdef12?edit=1'), findsOneWidget);
  });

  testWidgets('locks the rating once the edit window has passed',
      (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(
        rating: 5,
        ratedAt: _completedTwoDaysAgo,
        completedAt: _completedTwoDaysAgo,
      ),
      payment: null,
    );

    expect(find.text('5 out of 5'), findsOneWidget);
    expect(
      find.text('Ratings cannot be changed after 24 hours'),
      findsOneWidget,
    );
    expect(find.text('Tap to change your rating'), findsNothing);
  });

  testWidgets('a driver sees the rating received, read-only', (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(rating: 5, ratingComment: 'Safe', ratedAt: _completedJustNow),
      payment: null,
      asDriver: true,
    );

    expect(find.text('Passenger rating'), findsOneWidget);
    expect(find.text('5 out of 5'), findsOneWidget);
    expect(find.text('Tap to change your rating'), findsNothing);
    expect(find.text('Rate your driver'), findsNothing);
  });

  testWidgets('reports a load failure with a retry', (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(),
      payment: null,
      rideError: Exception('network down'),
    );

    expect(find.text('network down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('does not overflow on a small screen with large text',
      (tester) async {
    await _pumpDetails(
      tester,
      ride: _ride(),
      payment: RidePayment(
        id: 'pay-1',
        rideId: 'ride-abcdef12',
        amount: 90,
        method: 'cash',
        status: 'completed',
        createdAt: DateTime(2026, 1, 1, 9, 36),
      ),
      size: const Size(320, 480),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
  });
}
