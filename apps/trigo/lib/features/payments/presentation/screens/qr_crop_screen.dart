import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/services/qr_crop_processor.dart';
import '../../../../shared/widgets/app_top_bar.dart';

/// What the crop screen hands back: either the cropped PNG or a request to
/// pick a different photo.
class QrCropResult {
  const QrCropResult.use(this.bytes) : retake = false;
  const QrCropResult.retake()
      : bytes = null,
        retake = true;

  final Uint8List? bytes;
  final bool retake;
}

/// Lets the driver adjust the automatically detected QR crop before saving.
///
/// The box starts on the detected QR square (or the fallback centred square
/// when detection failed) and can be dragged or resized corner by corner, so
/// the automatic crop is always a starting point rather than a final answer.
class QrCropScreen extends StatefulWidget {
  const QrCropScreen({super.key, required this.detection});

  final QrDetection detection;

  @override
  State<QrCropScreen> createState() => _QrCropScreenState();
}

enum _DragMode { move, topLeft, topRight, bottomLeft, bottomRight }

class _QrCropScreenState extends State<QrCropScreen> {
  /// Hit radius for a corner handle, in logical pixels.
  static const double _handleHitRadius = 32;

  /// Drawn handle size, in logical pixels.
  static const double _handleSize = 22;

  late Rect _rect;
  bool _isCropping = false;

  /// Box size of the displayed image, set by the layout builder.
  Size _viewSize = Size.zero;

  _DragMode? _mode;
  Rect _dragStartRect = Rect.zero;
  Offset _dragStartLocal = Offset.zero;

  @override
  void initState() {
    super.initState();
    _rect = widget.detection.region;
  }

  void _resetToDetected() {
    setState(() {
      _rect = widget.detection.wasDetected
          ? widget.detection.region
          : QrCropProcessor.defaultCropRect(widget.detection.imageSize);
    });
  }

  Rect get _rectInView => Rect.fromLTRB(
        _rect.left * _viewSize.width,
        _rect.top * _viewSize.height,
        _rect.right * _viewSize.width,
        _rect.bottom * _viewSize.height,
      );

  _DragMode? _hitTest(Offset local) {
    final rect = _rectInView;
    final corners = <_DragMode, Offset>{
      _DragMode.topLeft: rect.topLeft,
      _DragMode.topRight: rect.topRight,
      _DragMode.bottomLeft: rect.bottomLeft,
      _DragMode.bottomRight: rect.bottomRight,
    };

    for (final entry in corners.entries) {
      if ((local - entry.value).distance <= _handleHitRadius) return entry.key;
    }
    if (rect.contains(local)) return _DragMode.move;
    return null;
  }

  void _onPanStart(DragStartDetails details) {
    final mode = _hitTest(details.localPosition);
    if (mode == null) return;
    setState(() {
      _mode = mode;
      _dragStartRect = _rectInView;
      _dragStartLocal = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final mode = _mode;
    if (mode == null || _viewSize.width <= 0 || _viewSize.height <= 0) return;

    final delta = details.localPosition - _dragStartLocal;
    final start = _dragStartRect;
    final maxX = _viewSize.width;
    final maxY = _viewSize.height;
    final minWidth = QrCropProcessor.minCropFraction * maxX;
    final minHeight = QrCropProcessor.minCropFraction * maxY;

    final Rect next;
    switch (mode) {
      case _DragMode.move:
        // Sliding keeps the box size, so it only needs to stay on the image.
        final left =
            (start.left + delta.dx).clamp(0.0, math.max(0.0, maxX - start.width));
        final top =
            (start.top + delta.dy).clamp(0.0, math.max(0.0, maxY - start.height));
        next = Rect.fromLTWH(left.toDouble(), top.toDouble(), start.width, start.height);
      case _DragMode.topLeft:
        next = Rect.fromLTRB(
          (start.left + delta.dx)
              .clamp(0.0, math.max(0.0, start.right - minWidth))
              .toDouble(),
          (start.top + delta.dy)
              .clamp(0.0, math.max(0.0, start.bottom - minHeight))
              .toDouble(),
          start.right,
          start.bottom,
        );
      case _DragMode.topRight:
        next = Rect.fromLTRB(
          start.left,
          (start.top + delta.dy)
              .clamp(0.0, math.max(0.0, start.bottom - minHeight))
              .toDouble(),
          (start.right + delta.dx)
              .clamp(math.min(maxX, start.left + minWidth), maxX)
              .toDouble(),
          start.bottom,
        );
      case _DragMode.bottomLeft:
        next = Rect.fromLTRB(
          (start.left + delta.dx)
              .clamp(0.0, math.max(0.0, start.right - minWidth))
              .toDouble(),
          start.top,
          start.right,
          (start.bottom + delta.dy)
              .clamp(math.min(maxY, start.top + minHeight), maxY)
              .toDouble(),
        );
      case _DragMode.bottomRight:
        next = Rect.fromLTRB(
          start.left,
          start.top,
          (start.right + delta.dx)
              .clamp(math.min(maxX, start.left + minWidth), maxX)
              .toDouble(),
          (start.bottom + delta.dy)
              .clamp(math.min(maxY, start.top + minHeight), maxY)
              .toDouble(),
        );
    }

    setState(() {
      _rect = QrCropProcessor.clampCropRect(
        Rect.fromLTRB(
          next.left / maxX,
          next.top / maxY,
          next.right / maxX,
          next.bottom / maxY,
        ),
      );
    });
  }

  void _onPanEnd() {
    setState(() => _mode = null);
  }

  Future<void> _crop() async {
    setState(() => _isCropping = true);
    try {
      final bytes = await QrCropProcessor.cropToPng(widget.detection, _rect);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not crop that area. Try again.')),
        );
        return;
      }
      Navigator.of(context).pop(QrCropResult.use(bytes));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCropping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = widget.detection.imageSize;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: const AppTopBar(
        title: 'Adjust QR Crop',
        fallbackLocation: '/driver/payment-methods',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.detection.wasDetected
                    ? 'We found the QR code and cropped to it. Drag the corners to adjust.'
                    : 'We could not find a QR code automatically. Move the box over the code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: imageSize.width <= 0 || imageSize.height <= 0
                        ? 1
                        : imageSize.width / imageSize.height,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _viewSize = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: (_) => _onPanEnd(),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RawImage(
                                image: widget.detection.image,
                                fit: BoxFit.fill,
                              ),
                              CustomPaint(
                                painter: _CropOverlayPainter(
                                  rect: _rectInView,
                                  handleSize: _handleSize,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.of(context).padding.bottom + 20,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isCropping ? null : () => Navigator.of(context).pop(const QrCropResult.retake()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCropping ? null : _resetToDetected,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCropping ? null : _crop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isCropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Use This Crop',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything outside the crop box and draws its border and handles.
class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.rect, required this.handleSize});

  final Rect rect;
  final double handleSize;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);

    final thirds = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = rect.left + rect.width * i / 3;
      final dy = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), thirds);
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), thirds);
    }

    final handle = Paint()..color = Colors.white;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: corner,
            width: handleSize,
            height: handleSize,
          ),
          const Radius.circular(6),
        ),
        handle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.handleSize != handleSize;
}
