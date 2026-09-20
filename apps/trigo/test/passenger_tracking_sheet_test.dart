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
                onCall: () {},
                onText: () {},
                onCompleteOrCancel: () {},
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

      expect(find.text('Complete Ride'), findsOneWidget);
      final action = tester.getRect(find.text('Complete Ride'));
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

    testWidgets('in_progress offers Complete Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'in_progress');
      expect(find.text('Complete Ride'), findsOneWidget);
    });

    testWidgets('completed offers Rate Driver', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'completed');
      expect(find.text('Rate Driver'), findsOneWidget);
    });
  });
}
