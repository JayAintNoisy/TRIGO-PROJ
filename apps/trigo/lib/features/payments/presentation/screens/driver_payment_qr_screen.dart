import 'dart:typed_data';

import 'package:dio/dio.dart' show DioMediaType;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/services/qr_crop_processor.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../../shared/widgets/authenticated_image.dart';
import '../../../driver_application/data/upload_repository.dart';
import '../../data/payment_methods_repository.dart';
import 'qr_crop_screen.dart';

/// Picks, post-processes and uploads the QR code that unlocks one of the
/// driver's payment methods.
///
/// The picked photo goes straight into [QrCropProcessor], which finds the QR
/// code and proposes a tight crop with a margin around it; the driver then
/// adjusts that crop before it is uploaded and the method is switched on.
class DriverPaymentQrScreen extends StatefulWidget {
  const DriverPaymentQrScreen({super.key, required this.method});

  /// Payment method id this QR code belongs to (`gcash`, `maya`, …).
  final String method;

  @override
  State<DriverPaymentQrScreen> createState() => _DriverPaymentQrScreenState();
}

class _DriverPaymentQrScreenState extends State<DriverPaymentQrScreen> {
  final _uploadRepository = UploadRepository();
  final _paymentsRepository = PaymentMethodsRepository();

  QrDetection? _detection;
  Uint8List? _croppedBytes;
  String? _existingQrUrl;
  bool _isLoadingExisting = true;
  bool _isBusy = false;
  String? _error;

  PaymentMethodMeta get _meta => PaymentMethods.byId(widget.method);

  @override
  void initState() {
    super.initState();
    _loadExistingQr();
  }

  @override
  void dispose() {
    _detection?.dispose();
    super.dispose();
  }

  /// Loads the QR code already configured for this method so the driver sees
  /// what is live instead of an empty drop zone.
  Future<void> _loadExistingQr() async {
    try {
      final methods = await _paymentsRepository.getDriverPaymentMethods();
      if (!mounted) return;
      final match = methods.where((m) => m.method == widget.method).toList();
      setState(() {
        _existingQrUrl =
            match.isEmpty ? null : match.first.qrCodeUrl;
        _isLoadingExisting = false;
      });
    } catch (_) {
      // A failed lookup only means we cannot show the current QR code.
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _error = null;
      _isBusy = true;
    });

    QrDetection? detection;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: 'Select your ${_meta.label} QR code',
      );
      if (picked == null) {
        if (mounted) setState(() => _isBusy = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isBusy = false;
            _error = 'That file is empty. Please pick another image.';
          });
        }
        return;
      }

      // Bounded decode + QR detection: this is the programmatic crop step.
      detection = await QrCropProcessor.detect(bytes);
      if (!mounted) {
        detection?.dispose();
        return;
      }
      if (detection == null) {
        setState(() {
          _isBusy = false;
          _error = 'That image could not be read. Please pick a JPG or PNG.';
        });
        return;
      }

      _detection?.dispose();
      _detection = detection;
      setState(() => _isBusy = false);
    } catch (e) {
      detection?.dispose();
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    await _openCropEditor();
  }

  /// Opens the adjustable crop view and keeps the resulting PNG.
  Future<void> _openCropEditor() async {
    final detection = _detection;
    if (detection == null) return;

    final result = await Navigator.of(context).push<QrCropResult>(
      MaterialPageRoute(
        builder: (routeContext) => QrCropScreen(detection: detection),
      ),
    );
    if (!mounted || result == null) return;

    if (result.retake) {
      await _pickImage();
      return;
    }

    setState(() {
      _croppedBytes = result.bytes;
      _error = null;
    });
  }

  Future<void> _save() async {
    final bytes = _croppedBytes;
    if (bytes == null) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final url = await _uploadRepository.uploadBytes(
        bytes,
        filename: 'qr.png',
        folder: 'payment-qr',
        contentType: DioMediaType('image', 'png'),
      );
      await _paymentsRepository.setDriverPaymentMethod(
        widget.method,
        isEnabled: true,
        qrCodeUrl: url,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cropped = _croppedBytes;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppTopBar(
        title: '${_meta.label} QR Code',
        fallbackLocation: '/driver/payment-methods',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _meta.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_meta.icon, color: _meta.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload your ${_meta.label} QR code',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pick a screenshot or photo of your QR code. We crop it to '
                    'the code automatically and you can adjust the crop before '
                    'saving. Passengers will scan it when they pay you.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (cropped != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        cropped,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'New cropped QR preview — save to replace the active one',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_existingQrUrl != null) ...[
              // The method is already configured: show the live QR code so the
              // driver can confirm what passengers will scan.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 220,
                        width: 220,
                        child: AuthenticatedImage(
                          url: absoluteUploadUrl(_existingQrUrl!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle,
                            size: 16, color: Color(0xFF059669)),
                        const SizedBox(width: 6),
                        Text(
                          'This QR code is active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_isLoadingExisting) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 44),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_2,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No QR code selected yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusy ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  cropped != null
                      ? 'Choose Another Image'
                      : _existingQrUrl != null
                          ? 'Replace QR Code'
                          : 'Choose Image',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (cropped != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isBusy ? null : _save,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Save & Enable ${_meta.label}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
