import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_input.dart';
import '../../../ride_booking/data/rides_repository.dart';

class DriverApplicationScreen extends ConsumerStatefulWidget {
  const DriverApplicationScreen({super.key});

  @override
  ConsumerState<DriverApplicationScreen> createState() =>
      _DriverApplicationScreenState();
}

class _DriverApplicationScreenState
    extends ConsumerState<DriverApplicationScreen> {
  final _licenseController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _repository = DriversRepository();
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submitApplication() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await _repository.apply(
        municipalityId: '934d7d07-2e3b-440d-8fd4-26a9340143bb',
        licenseNumber: _licenseController.text,
        tricyclePlateNumber: _plateController.text,
        tricycleModel: _modelController.text.isNotEmpty
            ? _modelController.text
            : null,
        documents: [
          {
            'documentType': 'license',
            'documentUrl': 'https://example.com/license.jpg',
          },
        ],
      );
      if (mounted) context.go('/driver/status');
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Apply as Tricycle Driver')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Driver Verification Application',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const Text(
                'Submit license and tricycle details for admin verification',
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
                label: 'Submit Driver Application',
                isLoading: _isSubmitting,
                onPressed: _submitApplication,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
