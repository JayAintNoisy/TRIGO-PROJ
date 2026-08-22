import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../data/upload_repository.dart';

class _DocumentSlot {
  final String label;
  final String documentType;
  final bool isRequired;
  bool isUploading = false;
  String? uploadedUrl;
  File? localPreview;

  _DocumentSlot({
    required this.label,
    required this.documentType,
    required this.isRequired,
  });
}

class DriverApplicationScreen extends ConsumerStatefulWidget {
  const DriverApplicationScreen({super.key});

  @override
  ConsumerState<DriverApplicationScreen> createState() =>
      _DriverApplicationScreenState();
}

class _DriverApplicationScreenState
    extends ConsumerState<DriverApplicationScreen> {
  final _repository = RidesRepository();
  final _driversRepository = DriversRepository();
  final _uploadRepository = UploadRepository();

  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();

  List<dynamic> _municipalities = [];
  String? _municipalityId;
  String? _rejectionReason;

  late final List<_DocumentSlot> _documents;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _documents = [
      _DocumentSlot(
        label: "Driver's License Photo",
        documentType: 'license_photo',
        isRequired: true,
      ),
      _DocumentSlot(
        label: 'Franchise Document (optional)',
        documentType: 'franchise_document',
        isRequired: false,
      ),
    ];
    _loadInitialState();
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    try {
      final results = await Future.wait([
        _repository.getMunicipalities(),
        _driversRepository.getMe().catchError((_) => null),
      ]);
      if (!mounted) return;
      final municipalities = results[0] as List<dynamic>;
      final profile = results[1];

      var redirect = false;
      if (profile != null) {
        final status = profile['applicationStatus'] as String?;
        if (status == 'pending' || status == 'reviewing') {
          redirect = true;
        } else if (status == 'rejected') {
          _rejectionReason = profile['rejectionReason'] as String?;
          _licenseController.text =
              (profile['licenseNumber'] as String?) ?? '';
          _plateController.text =
              (profile['tricyclePlateNumber'] as String?) ?? '';
          _modelController.text =
              (profile['tricycleModel'] as String?) ?? '';
          _municipalityId = profile['municipalityId'] as String?;
        }
      }
      if (redirect && mounted) {
        context.pushReplacement('/driver/status');
        return;
      }

      setState(() {
        _municipalities = municipalities;
        _municipalityId ??=
            municipalities.isNotEmpty ? municipalities.first['id'] as String : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDocument(_DocumentSlot slot) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (files.isEmpty || files.first.path == null || !mounted) return;

    final picked = files.first;
    final file = File(picked.path!);
    setState(() {
      slot.isUploading = true;
      slot.localPreview = file;
      _error = null;
    });

    try {
      final url = await _uploadRepository.uploadDocument(file);
      if (!mounted) return;
      setState(() {
        slot.uploadedUrl = url;
        slot.isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        slot.isUploading = false;
        slot.localPreview = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _validateForm() {
    if (_licenseController.text.trim().length < 3 ||
        _plateController.text.trim().length < 3) {
      setState(() => _error =
          'Enter your driver\u2019s license number and tricycle plate number');
      return false;
    }
    if (_municipalityId == null) {
      setState(() => _error = 'Select your service municipality');
      return false;
    }
    for (final slot in _documents) {
      if (slot.isRequired && (slot.uploadedUrl == null)) {
        setState(() => _error = 'Please upload ${slot.label}');
        return false;
      }
    }
    return true;
  }

  Future<void> _submitApplication() async {
    if (!_validateForm()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _driversRepository.apply(
        municipalityId: _municipalityId!,
        licenseNumber: _licenseController.text.trim(),
        tricyclePlateNumber: _plateController.text.trim(),
        tricycleModel: _modelController.text.isNotEmpty
            ? _modelController.text.trim()
            : null,
        documents: [
          for (final slot in _documents)
            if (slot.uploadedUrl != null)
              {
                'documentType': slot.documentType,
                'documentUrl': slot.uploadedUrl!,
              },
        ],
      );
      // Mode stays passenger until an admin approves; the status screen
      // offers "Go to Driver Mode" once approved
      if (mounted) context.go('/driver/status');
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tricycle Details')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_rejectionReason != null)
                      _buildRejectionBanner(),
                    const Text(
                      'Driver Verification',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Submit license, tricycle details, and documents '
                      'for admin verification',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    AppInput(
                      label: 'Driver License Number',
                      hint: 'N01-12-345678',
                      controller: _licenseController,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Tricycle Plate Number',
                      hint: '123-ABC',
                      controller: _plateController,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      label: 'Tricycle Model (Optional)',
                      hint: 'Kawasaki Barako 175',
                      controller: _modelController,
                    ),
                    const SizedBox(height: 16),
                    _buildMunicipalityDropdown(),
                    const SizedBox(height: 24),
                    ..._documents.map(_buildDocumentTile),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    AppButton(
                      label: _rejectionReason != null
                          ? 'Resubmit Application'
                          : 'Submit for Review',
                      isLoading: _isSubmitting,
                      onPressed:
                          _isSubmitting ? null : _submitApplication,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRejectionBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your application was declined',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\u201C${_rejectionReason!}\u201D \u2014 update your details below '
                  'and resubmit.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMunicipalityDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _municipalityId,
      decoration: InputDecoration(
        labelText: 'Service Municipality',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: [
        for (final m in _municipalities)
          DropdownMenuItem(
            value: m['id'] as String,
            child: Text(m['name'] as String),
          ),
      ],
      onChanged: (value) => setState(() => _municipalityId = value),
    );
  }

  Widget _buildDocumentTile(_DocumentSlot slot) {
    final hasFile = slot.localPreview != null;
    final isImage = hasFile &&
        (slot.localPreview!.path.toLowerCase().endsWith('.jpg') ||
            slot.localPreview!.path.toLowerCase().endsWith('.jpeg') ||
            slot.localPreview!.path.toLowerCase().endsWith('.png') ||
            slot.localPreview!.path.toLowerCase().endsWith('.webp'));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFFF1F5F9),
              child: slot.isUploading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasFile
                      ? (isImage
                          ? Image.file(slot.localPreview!,
                              fit: BoxFit.cover)
                          : const Icon(Icons.picture_as_pdf,
                              color: Color(0xFFEF4444)))
                      : const Icon(Icons.upload_file,
                          color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.isUploading
                      ? 'Uploading\u2026'
                      : slot.uploadedUrl != null
                          ? 'Uploaded'
                          : 'JPG, PNG, WEBP or PDF \u00b7 max 5 MB',
                  style: TextStyle(
                    fontSize: 11,
                    color: slot.uploadedUrl != null
                        ? const Color(0xFF059669)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: slot.isUploading ? null : () => _pickDocument(slot),
            child: Text(hasFile ? 'Replace' : 'Browse'),
          ),
        ],
      ),
    );
  }
}
