import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/payments/data/payment_methods_repository.dart';

/// Pure helpers around the payment method payloads.
void main() {
  setUp(() {
    // `ApiEndpoints.baseUrl` reads the dotenv map loaded at app boot.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://10.0.2.2:4000/api');
  });

  group('absoluteUploadUrl', () {
    test('keeps the API mount prefix from the configured base URL', () {
      // The uploads route lives under /api, so resolving from the host root
      // (which drops /api) silently 404s every QR image.
      expect(
        absoluteUploadUrl(
          '/uploads/payment-qr/31b27173-d6e4-4a05-ab5b-56df975ebcc8.png',
        ),
        'http://10.0.2.2:4000/api/uploads/payment-qr/31b27173-d6e4-4a05-ab5b-56df975ebcc8.png',
      );
    });

    test('accepts a path without a leading slash', () {
      expect(
        absoluteUploadUrl('uploads/payment-qr/qr.png'),
        'http://10.0.2.2:4000/api/uploads/payment-qr/qr.png',
      );
    });

    test('leaves an absolute URL untouched', () {
      expect(
        absoluteUploadUrl('https://cdn.example.com/qr.png'),
        'https://cdn.example.com/qr.png',
      );
    });
  });

  group('EnabledPaymentMethod.listFrom', () {
    test('parses the driver payment methods payload', () {
      final methods = EnabledPaymentMethod.listFrom([
        {'method': 'cash', 'qrCodeUrl': null},
        {
          'method': 'gcash',
          'qrCodeUrl': '/uploads/payment-qr/31b27173-d6e4-4a05-ab5b-56df975ebcc8.png',
        },
      ]);

      expect(methods.map((m) => m.method), ['cash', 'gcash']);
      expect(methods.last.qrCodeUrl, contains('/uploads/payment-qr/'));
    });

    test('falls back to cash when the payload is missing or malformed', () {
      expect(EnabledPaymentMethod.listFrom(null).single.method, 'cash');
      expect(EnabledPaymentMethod.listFrom(const []).single.method, 'cash');
      expect(EnabledPaymentMethod.listFrom([1, 'gcash']).single.method, 'cash');
    });
  });
}
