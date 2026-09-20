import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/presentation/widgets/driver_ride_tracking_sheet.dart';

/// The driver tracking sheet previously used fixed sizes throughout, so it
/// overflowed on short screens and with large OS font scales.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  String status = 'accepted',
  String pickup = 'Purok 3, Barangay San Isidro, Santa Rosa, Laguna',
  String dropoff =
      'Unit 1204, Tower B, Grand Residences, Ortigas Center, Pasig City',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Mirrors the real usage: a bottom-anchored sheet in a Stack.
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DriverRideTrackingSheet(
                passengerName: 'Juan Dela Cruz',
                passengerCount: 2,
                pickupAddress: pickup,
                dropoffAddress: dropoff,
                fare: '\u20B185',
                status: status,
                isActioning: false,
                onCall: () {},
                onText: () {},
                onStepAction: () {},
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
  group('driver tracking sheet adaptivity', () {
    testWidgets('tall phone: renders the progression action', (tester) async {
      await _pumpSheet(tester, size: const Size(411, 891), textScale: 1.0);
      _expectNoOverflow(tester);

      expect(find.text('Arrived'), findsOneWidget);
      expect(find.text('Current Fare'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
    });

    testWidgets('short landscape: no overflow, action stays on screen',
        (tester) async {
      await _pumpSheet(tester, size: const Size(891, 411), textScale: 1.0);
      _expectNoOverflow(tester);

      final action = tester.getRect(find.text('Arrived'));
      expect(action.bottom, lessThanOrEqualTo(411.0),
          reason: 'the progression button must stay within the viewport');
      expect(action.top, greaterThanOrEqualTo(0.0));
    });

    testWidgets('very small screen: no overflow', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);
      _expectNoOverflow(tester);
      expect(find.text('Arrived'), findsOneWidget);
    });

    testWidgets('large font scale: no overflow', (tester) async {
      await _pumpSheet(tester, size: const Size(411, 891), textScale: 2.0);
      _expectNoOverflow(tester);
      expect(find.text('Arrived'), findsOneWidget);
    });

    testWidgets('large font scale on a small screen: no overflow',
        (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.8);
      _expectNoOverflow(tester);
    });

    testWidgets('sheet never exceeds the viewport height', (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final sheet = tester.getRect(find.byType(DriverRideTrackingSheet));
      expect(sheet.height, lessThanOrEqualTo(h),
          reason: 'the sheet is capped at a fraction of the viewport');
    });

    testWidgets('very long addresses do not overflow', (tester) async {
      await _pumpSheet(
        tester,
        size: const Size(320, 480),
        textScale: 1.0,
        pickup: 'Purok 3, Barangay San Isidro, Santa Rosa, Laguna, Philippines'
            ' near the covered court beside the barangay hall',
        dropoff:
            'Unit 1204, Tower B, Grand Residences, Ortigas Center, Pasig City'
            ' corner of ADB Avenue and Garnet Road',
      );
      _expectNoOverflow(tester);
    });
  });

  group('sheet leaves room for the map', () {
    testWidgets('small screen: sheet stays under half the viewport',
        (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final sheet = tester.getRect(find.byType(DriverRideTrackingSheet));
      expect(sheet.height, lessThanOrEqualTo(h * 0.5),
          reason: 'the map must remain the majority of a small screen');
    });

    testWidgets('small screen: the map keeps the larger share', (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final sheet = tester.getRect(find.byType(DriverRideTrackingSheet));
      expect(h - sheet.height, greaterThan(sheet.height),
          reason: 'free map area must exceed the sheet area');
    });
  });

  group('collapsing the sheet', () {
    testWidgets('starts expanded and can fold to reveal the map',
        (tester) async {
      const h = 480.0;
      await _pumpSheet(tester, size: const Size(320, h), textScale: 1.0);
      _expectNoOverflow(tester);

      final expanded = tester.getRect(find.byType(DriverRideTrackingSheet));
      expect(find.text('Hide details'), findsOneWidget);
      expect(find.text('Current Fare'), findsOneWidget);

      // Tap the header to fold.
      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);

      final collapsed = tester.getRect(find.byType(DriverRideTrackingSheet));
      expect(collapsed.height, lessThan(expanded.height),
          reason: 'folding must shrink the sheet');
      expect(find.text('Show details'), findsOneWidget);
      expect(find.text('Current Fare'), findsNothing,
          reason: 'the detail body is hidden while folded');
    });

    testWidgets('the progression action stays usable while folded',
        (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);
      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);

      // The driver must always be able to advance the ride.
      expect(find.text('Arrived'), findsOneWidget);
      final action = tester.getRect(find.text('Arrived'));
      expect(action.bottom, lessThanOrEqualTo(480.0));
    });

    testWidgets('folding then unfolding restores the details', (tester) async {
      await _pumpSheet(tester, size: const Size(320, 480), textScale: 1.0);

      await tester.tap(find.text('Hide details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Current Fare'), findsNothing);

      await tester.tap(find.text('Show details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _expectNoOverflow(tester);
      expect(find.text('Current Fare'), findsOneWidget);
      expect(find.text('Hide details'), findsOneWidget);
    });
  });

  group('progression label per status', () {
    testWidgets('accepted shows Arrived', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'accepted');
      expect(find.text('Arrived'), findsOneWidget);
    });

    testWidgets('driver_arriving shows Start Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891),
          textScale: 1.0,
          status: 'driver_arriving');
      expect(find.text('Start Ride'), findsOneWidget);
    });

    testWidgets('in_progress shows Complete Ride', (tester) async {
      await _pumpSheet(tester,
          size: const Size(411, 891), textScale: 1.0, status: 'in_progress');
      expect(find.text('Complete Ride'), findsOneWidget);
    });
  });
}
