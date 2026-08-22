import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';

/// Maps backend application_status values to user-facing labels
String statusLabel(String status) {
  switch (status) {
    case 'reviewing':
      return 'Under Review';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Declined';
    case 'suspended':
      return 'Suspended';
    case 'pending':
    default:
      return 'For Review';
  }
}

class DriverStatusScreen extends ConsumerStatefulWidget {
  const DriverStatusScreen({super.key});

  @override
  ConsumerState<DriverStatusScreen> createState() =>
      _DriverStatusScreenState();
}

class _DriverStatusScreenState extends ConsumerState<DriverStatusScreen> {
  final _repository = DriversRepository();
  Timer? _pollTimer;
  dynamic _profile;
  bool _isLoading = true;

  String get _status => _profile?['applicationStatus'] ?? 'pending';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Admin decisions appear without leaving the screen
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadProfile());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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

  int get _currentStep {
    switch (_status) {
      case 'approved':
      case 'rejected':
      case 'suspended':
        return 3;
      case 'reviewing':
        return 2;
      case 'pending':
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Application Status'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildHeaderIcon(),
                      const SizedBox(height: 20),
                      Text(
                        statusLabel(_status),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'The TriGo admin team is verifying your '
                        'tricycle details and documents.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 28),
                      _buildStepper(),
                      if (_status == 'rejected') ...[
                        const SizedBox(height: 8),
                        _buildRejectionCard(),
                      ],
                      const SizedBox(height: 32),
                      _buildActions(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    final Color bgColor;
    final IconData iconData;
    final Color iconColor;
    switch (_status) {
      case 'approved':
        bgColor = const Color(0xFFD1FAE5);
        iconData = Icons.check_circle;
        iconColor = const Color(0xFF10B981);
        break;
      case 'rejected':
      case 'suspended':
        bgColor = const Color(0xFFFEE2E2);
        iconData = Icons.cancel;
        iconColor = const Color(0xFFEF4444);
        break;
      default:
        bgColor = const Color(0xFFDBEAFE);
        iconData = Icons.hourglass_top;
        iconColor = const Color(0xFF2563EB);
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: bgColor,
      child: Icon(iconData, size: 44, color: iconColor),
    );
  }

  Widget _buildStepper() {
    final steps = [
      ('Submitted', Icons.description_outlined),
      ('For Review', Icons.inbox_outlined),
      ('Under Review', Icons.manage_search),
      (_status == 'rejected' ? 'Declined' : 'Decision', Icons.gavel_outlined),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _buildStepRow(
              index: i,
              title: steps[i].$1,
              icon: steps[i].$2,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required int index,
    required String title,
    required IconData icon,
    required bool isLast,
  }) {
    final isDone = index < _currentStep || (index == 3 && _isDecisionMade);
    final isCurrent = index == _currentStep && !_isDecisionMade;

    final Color circleColor;
    final Color contentColor;
    if (index == 3 && _status == 'rejected') {
      circleColor = const Color(0xFFEF4444);
      contentColor = const Color(0xFFEF4444);
    } else if (isDone) {
      circleColor = const Color(0xFF10B981);
      contentColor = const Color(0xFF065F46);
    } else if (isCurrent) {
      circleColor = const Color(0xFF2563EB);
      contentColor = const Color(0xFF1E40AF);
    } else {
      circleColor = const Color(0xFFCBD5E1);
      contentColor = const Color(0xFF94A3B8);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(color: circleColor, shape: BoxShape.circle),
                child: Icon(
                  isDone ? Icons.check : icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: isLast ? 0 : 6, bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isCurrent || (index == 3 && _isDecisionMade)
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color: contentColor,
                    ),
                  ),
                  if (isCurrent)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isDecisionMade =>
      _status == 'approved' ||
      _status == 'rejected' ||
      _status == 'suspended';

  Widget _buildRejectionCard() {
    final reason =
        _profile?['rejectionReason'] as String? ?? 'No reason provided.';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
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
                  'Reason from the reviewing team',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
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

  Widget _buildActions() {
    if (_status == 'approved') {
      return AppButton(
        label: 'Go to Driver Mode',
        onPressed: () async {
          // Reflect the approval immediately, then open the driver home
          await ref.read(authProvider.notifier).refreshCurrentUser();
          if (mounted) context.go('/home');
        },
      );
    }
    if (_status == 'rejected') {
      return AppButton(
        label: 'Update & Resubmit',
        onPressed: () => context.go('/driver/apply'),
      );
    }
    return const SizedBox.shrink();
  }
}
