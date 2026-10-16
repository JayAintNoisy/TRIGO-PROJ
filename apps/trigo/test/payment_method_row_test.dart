import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trigo/core/constants/payment_methods.dart';
import 'package:trigo/features/payments/presentation/widgets/payment_method_row.dart';
import 'package:trigo/shared/widgets/authenticated_image.dart';

/// Driver payment method rows: cash is locked on, e-wallets unlock by QR.
Future<void> _pumpRow(
  WidgetTester tester, {
  required PaymentMethodMeta meta,
  required bool isEnabled,
  String? qrCodeUrl,
  bool isBusy = false,
  ValueChanged<bool>? onToggle,
  VoidCallback? onEditQr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PaymentMethodRow(
          meta: meta,
          isEnabled: isEnabled,
          isBusy: isBusy,
          qrCodeUrl: qrCodeUrl,
          onToggle: onToggle ?? (_) {},
          onEditQr: onEditQr ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    // The QR thumbnail asks for the stored token; an empty store answers null
    // and the widget falls back to its placeholder without any network call.
    SharedPreferences.setMockInitialValues({});
    // `ApiEndpoints.baseUrl` reads the dotenv map, which `main()` normally
    // loads at boot; without it every URL lookup throws.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  final cash = PaymentMethods.byId(PaymentMethods.cash);
  final gcash = PaymentMethods.byId(PaymentMethods.gcash);

  testWidgets('cash is shown as always available with a locked switch',
      (tester) async {
    await _pumpRow(tester, meta: cash, isEnabled: true);

    expect(find.text('Cash'), findsOneWidget);
    expect(find.textContaining('Always available'), findsOneWidget);

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isTrue);
    expect(sw.onChanged, isNull, reason: 'cash can never be switched off');
  });

  testWidgets('an e-wallet without a QR code asks for one and cannot be on',
      (tester) async {
    await _pumpRow(tester, meta: gcash, isEnabled: false);

    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('Add a QR code to enable'), findsOneWidget);
    expect(find.byType(AuthenticatedImage), findsNothing);

    final sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.value, isFalse);
    expect(sw.onChanged, isNotNull);
  });

  testWidgets('toggling an e-wallet reports the requested state', (tester) async {
    final toggles = <bool>[];
    await _pumpRow(
      tester,
      meta: gcash,
      isEnabled: false,
      onToggle: toggles.add,
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(toggles, [true]);
  });

  testWidgets('tapping an e-wallet row opens the QR flow', (tester) async {
    var taps = 0;
    await _pumpRow(
      tester,
      meta: gcash,
      isEnabled: false,
      onEditQr: () => taps++,
    );

    await tester.tap(find.text('GCash'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('a saved QR code is previewed on the row', (tester) async {
    await _pumpRow(
      tester,
      meta: gcash,
      isEnabled: true,
      qrCodeUrl: '/uploads/payment-qr/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee.png',
    );

    expect(find.byType(AuthenticatedImage), findsOneWidget);
    expect(find.textContaining('Enabled'), findsOneWidget);
  });

  testWidgets('a busy row shows progress instead of a switch', (tester) async {
    await _pumpRow(tester, meta: gcash, isEnabled: false, isBusy: true);

    expect(find.byType(Switch), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
