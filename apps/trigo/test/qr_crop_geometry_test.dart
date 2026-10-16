import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/shared/services/qr_crop_processor.dart';

/// Geometry of the QR crop box.
///
/// These cases cover the pure maths only: the dart:ui decode/encode wrapper is
/// exercised on a device, but the box that decides what gets cropped is
/// verified here without an engine.
void main() {
  const imageSize = Size(1000, 1000);

  group('qrRectFromFinderPoints', () {
    test('expands three finder centres into the whole code (known version)', () {
      // Version 1 is 21 modules; with 10px modules its finder centres sit
      // 35px in from the edges and the code spans 210px.
      final rect = qrRectFromFinderPoints(
        points: const [Offset(35, 35), Offset(175, 35), Offset(35, 175)],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      expect(rect.left, closeTo(0.0, 0.001));
      expect(rect.top, closeTo(0.0, 0.001));
      expect(rect.width, closeTo(0.21, 0.002));
      expect(rect.height, closeTo(0.21, 0.002));
    });

    test('falls back to a generous box when the version is unknown', () {
      final withVersion = qrRectFromFinderPoints(
        points: const [Offset(35, 35), Offset(175, 35), Offset(35, 175)],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;
      final withoutVersion = qrRectFromFinderPoints(
        points: const [Offset(35, 35), Offset(175, 35), Offset(35, 175)],
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      // Assuming the smallest QR keeps the box generous: it must never be
      // smaller than the true code.
      expect(withoutVersion.left, lessThanOrEqualTo(withVersion.left + 0.001));
      expect(
        withoutVersion.right,
        greaterThanOrEqualTo(withVersion.right - 0.001),
      );
    });

    test('an unknown version still fully covers a large code', () {
      // A version 10 code (57 modules, 10px modules) has finder centres 500px
      // apart; without the version the box must still contain the whole code.
      final rect = qrRectFromFinderPoints(
        points: const [Offset(35, 35), Offset(535, 35), Offset(35, 535)],
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      expect(rect.left, lessThanOrEqualTo(0.0));
      expect(rect.top, lessThanOrEqualTo(0.0));
      expect(rect.right, greaterThanOrEqualTo(0.57));
      expect(rect.bottom, greaterThanOrEqualTo(0.57));
    });

    test('handles a rotated code by bounding its diamond', () {
      // Version 1 code, 10px modules, rotated 45° about (500, 500).
      const d = 0.7071067811865476;
      const tl = Offset(500, 401);
      const tr = Offset(500 + 140 * d, 500);
      const bl = Offset(500 - 140 * d, 500);

      final rect = qrRectFromFinderPoints(
        points: [tl, tr, bl],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      // The rotated square's bounding box is a centred 297px box.
      expect(rect.left, closeTo(0.3515, 0.005));
      expect(rect.top, closeTo(0.3515, 0.005));
      expect(rect.width, closeTo(0.297, 0.01));
      expect(rect.height, closeTo(0.297, 0.01));
    });

    test('clamps to the image edges', () {
      final rect = qrRectFromFinderPoints(
        points: const [Offset(5, 5), Offset(145, 5), Offset(5, 145)],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      expect(rect.left, 0.0);
      expect(rect.top, 0.0);
      expect(rect.right, closeTo(0.18, 0.01));
      expect(rect.bottom, closeTo(0.18, 0.01));
    });

    test('picks the finder patterns when an alignment point is also reported',
        () {
      final withAlignment = qrRectFromFinderPoints(
        points: const [
          Offset(35, 35),
          Offset(175, 35),
          Offset(35, 175),
          Offset(140, 140),
        ],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;

      expect(withAlignment.width, closeTo(0.21, 0.002));
      expect(withAlignment.height, closeTo(0.21, 0.002));
    });

    test('keeps a margin around the detected code', () {
      final tight = qrRectFromFinderPoints(
        points: const [Offset(200, 200), Offset(400, 200), Offset(200, 400)],
        version: 1,
        imageSize: imageSize,
        marginFraction: 0,
      )!;
      final padded = qrRectFromFinderPoints(
        points: const [Offset(200, 200), Offset(400, 200), Offset(200, 400)],
        version: 1,
        imageSize: imageSize,
      )!;

      expect(padded.width, greaterThan(tight.width));
      expect(padded.left, lessThan(tight.left));
      expect(padded.top, lessThan(tight.top));
    });

    test('returns null when there are not three usable points', () {
      expect(
        qrRectFromFinderPoints(
          points: const [Offset(10, 10), Offset(20, 20)],
          version: 1,
          imageSize: imageSize,
        ),
        isNull,
      );
      expect(
        qrRectFromFinderPoints(
          points: const [Offset(10, 10), Offset(10, 10), Offset(10, 10)],
          version: 1,
          imageSize: imageSize,
        ),
        isNull,
      );
    });
  });

  group('defaultCropRect', () {
    test('is a centred square based on the shorter side', () {
      final rect = QrCropProcessor.defaultCropRect(const Size(1000, 500));

      expect(rect.width, closeTo(0.35, 0.001));
      expect(rect.height, closeTo(0.7, 0.001));
      expect(rect.left, closeTo(0.325, 0.001));
      expect(rect.top, closeTo(0.15, 0.001));
    });
  });

  group('clampCropRect', () {
    test('pushes a box back inside the image', () {
      final rect = QrCropProcessor.clampCropRect(
        const Rect.fromLTWH(0.8, 0.8, 0.5, 0.5),
      );

      expect(rect.right, lessThanOrEqualTo(1.0));
      expect(rect.bottom, lessThanOrEqualTo(1.0));
      expect(rect.width, 0.5);
    });

    test('enforces the minimum selectable size', () {
      final rect = QrCropProcessor.clampCropRect(
        const Rect.fromLTWH(0.4, 0.4, 0.01, 0.01),
        minWidth: QrCropProcessor.minCropFraction,
        minHeight: QrCropProcessor.minCropFraction,
      );

      // Rect stores LTRB internally, so compare with a tolerance.
      expect(rect.width, closeTo(QrCropProcessor.minCropFraction, 1e-9));
      expect(rect.height, closeTo(QrCropProcessor.minCropFraction, 1e-9));
    });
  });
}
