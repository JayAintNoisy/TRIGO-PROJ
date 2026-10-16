import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/ride_booking/presentation/widgets/incoming_request_modal.dart';

/// Pumps the modal at a given logical size / font scale and asserts the
/// render tree raises no overflow, then exercises both buttons.
Future<void> _pumpModal(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  Map<String, dynamic>? ride,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final data = ride ??
      <String, dynamic>{
        'customerName': 'Juan Dela Cruz',
        'fareEstimate': 85,
        'distanceKm': 4.2,
        'pickupAddress': 'Purok 3, Barangay San Isidro, Santa Rosa, Laguna',
        'dropoffAddress':
            'Unit 1204, Tower B, Grand Residences, Ortigas Center, Pasig City',
      };

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  IncomingRequestModal.show(context, data, () async {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  // The pulse icon repeats forever, so pumpAndSettle can never settle.
  // Pump a bounded number of frames instead.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fails with a readable message if any RenderFlex overflowed.
void _expectNoOverflow(WidgetTester tester) {
  final errors = tester.takeException();
  expect(errors, isNull, reason: 'Overflow/exception raised: $errors');
}

void main() {
  // The duplicate-sheet guard is static, so it persists across tests in the
  // same isolate. Reset it so each test starts from a clean state.
  setUp(IncomingRequestModal.resetGuardForTesting);

  testWidgets('portrait tall phone: no overflow, buttons work', (tester) async {
    await _pumpModal(tester, size: const Size(411, 891), textScale: 1.0);
    _expectNoOverflow(tester);

    expect(find.text('ACCEPT RIDE'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ACCEPT RIDE'), findsNothing,
        reason: 'Decline should dismiss the modal');
  });

  testWidgets('short landscape: no overflow, actions remain reachable',
      (tester) async {
    await _pumpModal(tester, size: const Size(891, 411), textScale: 1.0);
    _expectNoOverflow(tester);

    // Pinned buttons must be laid out inside the viewport.
    final accept = tester.getRect(find.text('ACCEPT RIDE'));
    expect(accept.bottom, lessThanOrEqualTo(411.0),
        reason: 'ACCEPT RIDE must stay within the viewport');
    expect(accept.top, greaterThanOrEqualTo(0.0));

    await tester.tap(find.text('ACCEPT RIDE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ACCEPT RIDE'), findsNothing,
        reason: 'ACCEPT RIDE should dismiss the modal');
  });

  testWidgets('large font scale: no overflow', (tester) async {
    await _pumpModal(tester, size: const Size(411, 891), textScale: 2.0);
    _expectNoOverflow(tester);
    expect(find.text('ACCEPT RIDE'), findsOneWidget);
  });

  testWidgets('very small screen: body scrolls, buttons stay put',
      (tester) async {
    await _pumpModal(tester, size: const Size(320, 480), textScale: 1.0);
    _expectNoOverflow(tester);

    final accept = tester.getRect(find.text('ACCEPT RIDE'));
    expect(accept.bottom, lessThanOrEqualTo(480.0),
        reason: 'ACCEPT RIDE must stay within the viewport');
  });

  testWidgets('duplicate show() calls do not stack modals', (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const ride = <String, dynamic>{
      'customerName': 'Juan Dela Cruz',
      'fareEstimate': 85,
      'distanceKm': 4.2,
      'pickupAddress': 'Pickup',
      'dropoffAddress': 'Drop-off',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  // Simulates the poll and the map-pin tap firing together.
                  IncomingRequestModal.show(context, ride, () async {});
                  IncomingRequestModal.show(context, ride, () async {});
                },
                child: const Text('open twice'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open twice'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final errors = tester.takeException();
    expect(errors, isNull, reason: 'Exception raised: $errors');
    expect(find.text('ACCEPT RIDE'), findsOneWidget,
        reason: 'Only one modal should be on screen, not a stack');
  });

  testWidgets('guard releases so the modal can be shown again', (tester) async {
    await _pumpModal(tester, size: const Size(411, 891), textScale: 1.0);
    expect(find.text('ACCEPT RIDE'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ACCEPT RIDE'), findsNothing);

    // A later request must be able to present again.
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('ACCEPT RIDE'), findsOneWidget,
        reason: 'Guard must reset after the sheet closes');
  });

  group('accepting', () {
    /// Opens the modal with a controllable accept handler.
    Future<void> pumpWithHandler(
      WidgetTester tester,
      Future<void> Function() onAccept,
    ) async {
      tester.view.physicalSize = const Size(411, 891);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => IncomingRequestModal.show(
                    context,
                    <String, dynamic>{'customerName': 'Juan'},
                    onAccept,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('closes as soon as the accept handler returns',
        (tester) async {
      var accepted = 0;
      await pumpWithHandler(tester, () async {
        accepted++;
      });

      await tester.tap(find.text('ACCEPT RIDE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(accepted, 1);
      expect(find.text('ACCEPT RIDE'), findsNothing,
          reason: 'the offer must not linger once it has been taken');
    });

    testWidgets('stops spinning and closes when accepting fails',
        (tester) async {
      await pumpWithHandler(tester, () async {
        throw Exception('This ride has already been accepted');
      });

      await tester.tap(find.text('ACCEPT RIDE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('ACCEPT RIDE'), findsNothing);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a failed accept must not leave the button loading forever',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a handler that outlives the trip screen still closes the sheet',
        (tester) async {
      // The real caller used to await the navigation that follows acceptance,
      // which resolves only when the tracking screen is popped — leaving this
      // sheet (and its spinner) on screen for the whole ride. The sheet must be
      // gone as soon as the handler returns, whatever happens afterwards.
      await pumpWithHandler(tester, () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.tap(find.text('ACCEPT RIDE'));
      await tester.pump();

      // While the handler is still pending the button shows progress.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let the handler finish, then let the sheet's exit animation run: the
      // pulse icon repeats forever, so pumpAndSettle is not an option here.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ACCEPT RIDE'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
