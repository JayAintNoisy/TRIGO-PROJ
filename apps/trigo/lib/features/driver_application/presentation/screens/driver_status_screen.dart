import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_mode_switch.dart';

class DriverStatusScreen extends ConsumerStatefulWidget {
  const DriverStatusScreen({super.key});

  @override
  ConsumerState<DriverStatusScreen> createState() =>
      _DriverStatusScreenState();
}

class _DriverStatusScreenState
    extends ConsumerState<DriverStatusScreen> {
  final _repository = DriversRepository();
  dynamic _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getMe();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        _profile?['applicationStatus'] ?? 'pending';
    final statusText = status == 'approved'
        ? 'Application Approved!'
        : status == 'rejected'
            ? 'Application Rejected'
            : 'Application Under Review';

    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: status == 'approved'
                          ? const Color(0xFFD1FAE5)
                          : status == 'rejected'
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFFEF08A),
                      child: Icon(
                        status == 'approved'
                            ? Icons.check_circle
                            : status == 'rejected'
                                ? Icons.cancel
                                : Icons.hourglass_top,
                        size: 44,
                        color: status == 'approved'
                            ? const Color(0xFF10B981)
                            : status == 'rejected'
                                ? const Color(0xFFEF4444)
                                : Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      statusText,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The TriGo Admin team is reviewing your documents.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: status == 'approved'
                          ? 'Go to Driver Mode'
                          : 'Return to Passenger Mode',
                      onPressed: () {
                        if (status == 'approved') {
                          ref.read(authProvider.notifier)
                              .toggleMode(
                                  AppUserMode.driver);
                        }
                        context.go('/home');
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
