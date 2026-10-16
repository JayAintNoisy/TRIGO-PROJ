import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:zxing2/qrcode.dart';

/// A decoded picked image plus the QR crop box found in it.
///
/// [image] is a bounded-resolution raster (see
/// [QrCropProcessor.maxDetectionSide]) used for both detection and cropping, so
/// a 12 MP phone photo never has to be held in memory at full size.
class QrDetection {
  QrDetection({
    required this.image,
    required this.imageSize,
    required this.region,
    required this.wasDetected,
  });

  final ui.Image image;
  final Size imageSize;

  /// Crop region in normalized 0..1 coordinates relative to [image].
  final Rect region;

  /// False when no QR code was found and [region] is the fallback square.
  final bool wasDetected;

  void dispose() => image.dispose();
}

/// Turns a picked photo into a tightly cropped QR code image.
///
/// The pipeline is: decode at a bounded size, detect the QR code's finder
/// patterns with zxing2, expand them into the full QR square plus a small
/// margin, and let the caller crop (possibly after the driver adjusts the
/// box). When detection fails, a centred square is offered instead so the
/// driver always has a usable starting point.
class QrCropProcessor {
  const QrCropProcessor._();

  /// Longest side of the raster used for detection and cropping.
  static const int maxDetectionSide = 1600;

  /// Longest side of the produced QR image.
  static const int maxOutputSide = 1024;

  /// Extra space kept around the detected QR code.
  static const double detectedMarginFraction = 0.04;

  /// Side of the fallback crop square, as a fraction of the shorter image side.
  static const double fallbackFraction = 0.7;

  /// Smallest crop the driver can select, as a fraction of the shorter side.
  static const double minCropFraction = 0.15;

  /// Decodes [bytes] and detects the QR code in it.
  ///
  /// Returns null only when the image cannot be decoded at all; a decodable
  /// image without a findable QR code still returns a [QrDetection] whose
  /// [QrDetection.wasDetected] is false.
  static Future<QrDetection?> detect(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);

    final longSide = math.max(descriptor.width, descriptor.height);
    int? targetWidth;
    int? targetHeight;
    if (longSide > maxDetectionSide) {
      // Never upscale: only shrink when the source is larger than the bound.
      if (descriptor.width >= descriptor.height) {
        targetWidth = maxDetectionSide;
      } else {
        targetHeight = maxDetectionSide;
      }
    }

    final codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    try {
      final result = await _decodeQr(image);
      final region = result == null
          ? null
          : qrRectFromFinderPoints(
              points: result.$1,
              version: result.$2,
              imageSize: imageSize,
            );

      if (region == null) {
        return QrDetection(
          image: image,
          imageSize: imageSize,
          region: defaultCropRect(imageSize),
          wasDetected: false,
        );
      }

      return QrDetection(
        image: image,
        imageSize: imageSize,
        region: region,
        wasDetected: true,
      );
    } catch (_) {
      image.dispose();
      rethrow;
    }
  }

  /// Crops [detection] to [normalizedRect] and encodes it as a PNG.
  ///
  /// The result is bounded to [maxOutputSide] on its longest side, which keeps
  /// the upload well inside the backend's 5 MB limit.
  static Future<Uint8List?> cropToPng(
    QrDetection detection,
    Rect normalizedRect,
  ) async {
    final rect = clampCropRect(normalizedRect);
    final srcWidth = rect.width * detection.imageSize.width;
    final srcHeight = rect.height * detection.imageSize.height;
    if (srcWidth < 1 || srcHeight < 1) return null;

    final scale = math.min(
      1.0,
      maxOutputSide / math.max(srcWidth, srcHeight),
    );
    final outWidth = math.max(1, (srcWidth * scale).round());
    final outHeight = math.max(1, (srcHeight * scale).round());

    final source = Rect.fromLTWH(
      rect.left * detection.imageSize.width,
      rect.top * detection.imageSize.height,
      srcWidth,
      srcHeight,
    );
    final destination =
        Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      detection.image,
      source,
      destination,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();

    try {
      final cropped = await picture.toImage(outWidth, outHeight);
      try {
        final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        cropped.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  /// Keeps a crop inside the image, optionally enforcing a minimum size.
  ///
  /// The detection path passes no minimum so an accurate box for a small QR
  /// code is never inflated; the interactive editor passes
  /// [minCropFraction] so the driver cannot drag the box down to nothing.
  static Rect clampCropRect(
    Rect rect, {
    double minWidth = 0,
    double minHeight = 0,
  }) {
    final width = rect.width.clamp(minWidth.clamp(0.0, 1.0), 1.0).toDouble();
    final height = rect.height.clamp(minHeight.clamp(0.0, 1.0), 1.0).toDouble();
    final maxLeft = math.max(0.0, 1.0 - width);
    final maxTop = math.max(0.0, 1.0 - height);
    final left = rect.left.clamp(0.0, maxLeft).toDouble();
    final top = rect.top.clamp(0.0, maxTop).toDouble();

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Centred square used when no QR code could be detected.
  static Rect defaultCropRect(Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }

    final side = fallbackFraction * math.min(imageSize.width, imageSize.height);
    return clampCropRect(
      Rect.fromCenter(
        center: const Offset(0.5, 0.5),
        width: side / imageSize.width,
        height: side / imageSize.height,
      ),
    );
  }

  static Future<(List<Offset>, int?)?> _decodeQr(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    final rgba = byteData.buffer.asUint8List();
    final pixels = Int32List(image.width * image.height);
    for (var i = 0, p = 0; i < pixels.length; i++, p += 4) {
      // RGBLuminanceSource expects ARGB-packed ints.
      pixels[i] = (rgba[p] << 16) | (rgba[p + 1] << 8) | rgba[p + 2];
    }

    try {
      final source = RGBLuminanceSource(image.width, image.height, pixels);
      // TRY_HARDER is a marker hint: its value is irrelevant, only presence.
      final hints = DecodeHints()..put(DecodeHintType.tryHarder);
      final result = QRCodeReader().decode(
        BinaryBitmap(HybridBinarizer(source)),
        hints: hints,
      );

      final points = result.resultPoints
          .map((point) => Offset(point.x, point.y))
          .toList(growable: false);
      return (points, result.version);
    } catch (_) {
      // NotFoundException / ChecksumException / FormatReaderException all mean
      // "no usable QR code here" — the caller falls back to a manual crop.
      return null;
    }
  }
}

/// Builds the QR square from the three finder-pattern centres returned by the
/// decoder.
///
/// [points] are in image pixel coordinates and [imageSize] is the decoded
/// raster's size; the result is normalized to 0..1. Returns null when the
/// points cannot form a usable quadrilateral. [version] (when known) gives the
/// exact module count, which makes the estimate precise; otherwise a mid-range
/// module count is assumed and the box is slightly generous.
Rect? qrRectFromFinderPoints({
  required List<Offset> points,
  int? version,
  required Size imageSize,
  double marginFraction = QrCropProcessor.detectedMarginFraction,
}) {
  if (imageSize.width <= 0 || imageSize.height <= 0) return null;
  if (points.length < 3) return null;

  final triple = _selectFinderTriple(points);
  if (triple == null) return null;

  // The right-angle vertex is the corner finder pattern (top-left for an
  // unrotated code); the other two are the ones it forms legs with.
  final legs = _rightAngleVertex(triple);
  if (legs == null) return null;
  final corner = legs.$1;
  final legA = legs.$2 - corner;
  final legB = legs.$3 - corner;

  final legALength = legA.distance;
  final legBLength = legB.distance;
  if (legALength <= 0 || legBLength <= 0) return null;

  // A QR code is 17 + 4 * version modules across. Without a reported version we
  // assume the smallest code (21 modules): that errs towards a generous box,
  // and an over-large crop is harmless while a clipped one is not.
  final modules = (version != null && version >= 0) ? 17 + 4 * version : 21;
  if (modules <= 7) return null;

  final legLength = math.max(legALength, legBLength);
  final moduleSize = legLength / (modules - 7);
  final side = modules * moduleSize;
  if (side <= 0 || !side.isFinite) return null;

  final unitA = legA / legALength;
  final unitB = legB / legBLength;

  // The corner finder centre sits 3.5 modules inside the code on both axes.
  final origin = corner - (unitA + unitB) * (3.5 * moduleSize);
  final corners = <Offset>[
    origin,
    origin + unitA * side,
    origin + unitB * side,
    origin + unitA * side + unitB * side,
  ];

  var minX = corners.first.dx;
  var maxX = corners.first.dx;
  var minY = corners.first.dy;
  var maxY = corners.first.dy;
  for (final point in corners) {
    minX = math.min(minX, point.dx);
    maxX = math.max(maxX, point.dx);
    minY = math.min(minY, point.dy);
    maxY = math.max(maxY, point.dy);
  }

  final margin = marginFraction * side;
  final left = (minX - margin).clamp(0.0, imageSize.width);
  final top = (minY - margin).clamp(0.0, imageSize.height);
  final right = (maxX + margin).clamp(0.0, imageSize.width);
  final bottom = (maxY + margin).clamp(0.0, imageSize.height);

  if (right <= left || bottom <= top) return null;

  return QrCropProcessor.clampCropRect(
    Rect.fromLTRB(
      left / imageSize.width,
      top / imageSize.height,
      right / imageSize.width,
      bottom / imageSize.height,
    ),
  );
}

/// Picks the three finder patterns when the decoder also reported an alignment
/// pattern: the finder patterns are the ones enclosing the largest triangle.
List<Offset>? _selectFinderTriple(List<Offset> points) {
  if (points.length == 3) return points;
  if (points.length > 6) return points.sublist(0, 3);

  List<Offset>? best;
  var bestArea = -1.0;
  for (var i = 0; i < points.length - 2; i++) {
    for (var j = i + 1; j < points.length - 1; j++) {
      for (var k = j + 1; k < points.length; k++) {
        final area = _triangleArea(points[i], points[j], points[k]);
        if (area > bestArea) {
          bestArea = area;
          best = [points[i], points[j], points[k]];
        }
      }
    }
  }
  return best;
}

double _triangleArea(Offset a, Offset b, Offset c) {
  return ((b.dx - a.dx) * (c.dy - a.dy) - (c.dx - a.dx) * (b.dy - a.dy)).abs() /
      2;
}

/// Returns `(corner, legEnd1, legEnd2)` for three finder centres, where
/// `corner` is the vertex opposite the longest side (the right angle).
(Offset, Offset, Offset)? _rightAngleVertex(List<Offset> triple) {
  final a = triple[0];
  final b = triple[1];
  final c = triple[2];

  final ab = (a - b).distance;
  final bc = (b - c).distance;
  final ca = (c - a).distance;

  if (ab >= bc && ab >= ca) return (c, a, b);
  if (bc >= ab && bc >= ca) return (a, b, c);
  return (b, a, c);
}
