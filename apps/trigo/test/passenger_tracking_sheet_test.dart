import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/presentation/widgets/passenger_ride_tracking_sheet.dart';

/// The passenger sheet now mirrors the driver sheet: adaptive to screen size,
/// height-capped so the map keeps the majority of a small screen, and
/// collapsible via a hide/show details control.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  String status = 'accepted',
  List<String> driverPaymentMethods = const [],
  String? selectedPaymentMethod,
  VoidCallback? onChoosePaymentMethod,
  VoidCallback? onCancelRide,
  VoidCallback? onRateDriver,
  VoidCallback? onMessage,
  bool hasDriver = true,
  int? existingRating,
  VoidCallback? onViewReceipt,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: PassengerRideTrackingSheet(
                statusText: 'Your driver is on the way',
                driverName: 'Juan Dela Cruz',
                plateNumber: 'ABC-1234',
                fare: '\u20B185',
                eta: '12 min',
                status: status,
                isActioning: false,
                driverPaymentMethods: driverPaymentMethods,
                selectedPaymentMethod: selectedPaymentMethod,
                onChoosePaymentMethod: onChoosePaymentMethod,
                onMessage: onMessage,
                hasDriver: hasDriver,
                existingRating: existingRating,
                onViewReceipt: onViewReceipt,
                onCall: () {},
                onText: () {},
                onCancelRide: onCancelRide ?? () {},
                onRateDriver: onRateDriver ?? () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void _expectNoOverflow(WidgetTester tester) {
  final e = tester.takeException();
  if (e is FlutterError) {
    // Which widget overflowed is only in the diagnostics, not the message.
    debugPrint(e.diagnostics.map((node) => node.toString()).join('\n'));
  }
  expect(e, isNull, reason: 'Overflow/exception raised: $e');
}

void main() {
  group('passenger sheet adaptivity', () {
    testWidgets('tall phone renders the details', (tester) async {
      await _pumpSheet(tester, size: const Size(411, 891), textScale: 1.0);
      _expectNoOverflow(tester);
      expect(find.text('Your driver is on the way'), findsOneWidget);
      expect(find.textContaining('ETA'), findsOneWidget);
      expect(find.textContaining('Fare'), findsOneWidget);
    });

    testWidgets('short landscape: no overflow', (tester) async {
      await _pumpSheet(tester, size: const Size(891, 411), textScale: 1.0);
      _expectNoOverflow(tester);
    });

    testWidgets('very small screen: no overflow', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);
      _expectNoOverflow(tester);
    });

    testWidgets('large font scale: no overflow', (tester) async {
      await _pumpSheet(tester, size: const Size(411, 891), textScale: 2.0);
      _expectNoOverflow(tester);
    });

    testWidgets('large font scale on a small screen: no overflow',
        (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.8);
      _expectNoOverflow(tester);
    });

    testWidgets('small screen: sheet stays under half the viewport',
        (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final sheet = tester.getRect(find.byType(PassengerRideTrackingSheet));
      expect(sheet.height, lessThanOrEqualTo(h * 0.5),
          reason: 'the map must remain the majority of a small screen');
    });
  });

  group('passenger sheet collapsing', () {
    testWidgets('starts expanded and folds to reveal the map', (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final expanded = tester.getRect(find.byType(PassengerRideTrackingSheet));
      expect(find.text('Hide details'), findsOneWidget);
      expect(find.textContaining('ETA'), findsOneWidget);

      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);

      final collapsed = tester.getRect(find.byType(PassengerRideTrackingSheet));
      expect(collapsed.height, lessThan(expanded.height));
      expect(find.text('Show details'), findsOneWidget);
      expect(find.textContaining('ETA'), findsNothing,
          reason: 'details are hidden while folded');
    });

    testWidgets('the primary action stays usable while folded', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);
      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);

      expect(find.text('Cancel Ride'), findsOneWidget);
      final action = tester.getRect(find.text('Cancel Ride'));
      expect(action.bottom, lessThanOrEqualTo(480.0));
    });

    testWidgets('folding then unfolding restores the details', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);

      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Fare'), findsNothing);

      await tester.tap(find.text('Show details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);
      expect(find.textContaining('Fare'), findsOneWidget);
    });
  });

  group('primary action label per status', () {
    testWidgets('requested offers Cancel Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'requested');
      expect(find.text('Cancel Ride'), findsOneWidget);
    });

    testWidgets('accepted offers Cancel Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'accepted');
      expect(find.text('Cancel Ride'), findsOneWidget);
    });

    testWidgets('driver_arriving still offers Cancel Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891),
          textScale: 1.0,
          status: 'driver_arriving');
      expect(find.text('Cancel Ride'), findsOneWidget);
    });

    testWidgets('in_progress hands the ride to the driver', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'in_progress');

      // No passenger action once the trip has started.
      expect(find.text('Complete Ride'), findsNothing);
      expect(find.text('Cancel Ride'), findsNothing);
      expect(find.text('Rate Driver'), findsNothing);
      expect(find.textContaining('your driver completes the ride'),
          findsOneWidget);
    });

    testWidgets('completed offers Rate Driver', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'completed');
      expect(find.text('Rate Driver'), findsOneWidget);
      expect(find.text('View Receipt'), findsNothing);
    });

    testWidgets('a completed trip that is already rated offers the receipt',
        (tester) async {
      var receipts = 0;
      var rates = 0;
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'completed',
        existingRating: 5,
        onRateDriver: () => rates++,
        onViewReceipt: () => receipts++,
      );

      expect(find.text('Rate Driver'), findsNothing);
      expect(find.text('View Receipt'), findsOneWidget);

      await tester.tap(find.text('View Receipt'));
      await tester.pump();

      expect(receipts, 1);
      expect(rates, 0, reason: 'a rated trip must not reopen the rating form');
    });

    testWidgets('cancel and rate callbacks stay separate', (tester) async {
      var cancels = 0;
      var rates = 0;
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'accepted',
        onCancelRide: () => cancels++,
        onRateDriver: () => rates++,
      );

      await tester.tap(find.text('Cancel Ride'));
      await tester.pump();

      expect(cancels, 1);
      expect(rates, 0);
    });
  });

  group('payment method row', () {
    testWidgets('is hidden until a driver accepts', (tester) async {
      await _pumpSheet(tester, size: const Size(411, 891), textScale: 1.0);

      expect(find.text('Payment method'), findsNothing);
    });

    testWidgets('shows cash as the default before the passenger chooses',
        (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'in_progress',
        driverPaymentMethods: const ['cash', 'gcash'],
        onChoosePaymentMethod: () {},
      );

      expect(find.text('Payment method'), findsOneWidget);
      expect(find.text('Cash (default)'), findsOneWidget);
    });

    testWidgets('shows the chosen method once one is set', (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'in_progress',
        driverPaymentMethods: const ['cash', 'gcash'],
        selectedPaymentMethod: 'gcash',
        onChoosePaymentMethod: () {},
      );

      expect(find.text('GCash'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('tapping the row asks for the payment chooser', (tester) async {
      var taps = 0;
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'in_progress',
        driverPaymentMethods: const ['cash', 'gcash'],
        onChoosePaymentMethod: () => taps++,
      );

      await tester.tap(find.text('Payment method'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('does not overflow a small screen with large text',
        (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(320, 480),
        textScale: 2.0,
        status: 'in_progress',
        driverPaymentMethods: const ['cash', 'gcash', 'maya'],
        onChoosePaymentMethod: () {},
      );

      _expectNoOverflow(tester);
    });
  });

  group('contact actions', () {
    testWidgets('are hidden until a driver is assigned', (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'requested',
        hasDriver: false,
        onMessage: () {},
      );

      expect(find.text('Call'), findsNothing);
      expect(find.text('Text'), findsNothing);
      expect(find.text('Message'), findsNothing);
    });

    testWidgets('offer Call, Text and in-app Message once a driver accepts',
        (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'accepted',
        onMessage: () {},
      );

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('message is omitted when no handler is wired', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'accepted');

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsNothing);
    });

    testWidgets('tapping Message opens the chat', (tester) async {
      var taps = 0;
      await _pumpSheet(
        tester,
        size: const Size(411, 891),
        textScale: 1.0,
        status: 'accepted',
        onMessage: () => taps++,
      );

      await tester.tap(find.text('Message'));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('three actions still fit a small screen with large text',
        (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(320, 480),
        textScale: 2.0,
        status: 'accepted',
        onMessage: () {},
      );

      expect(find.text('Message'), findsOneWidget);
      _expectNoOverflow(tester);
    });
  });
}
