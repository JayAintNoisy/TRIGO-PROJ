import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../shared/widgets/app_back_button.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String? rideId;
  const RideTrackingScreen({super.key, this.rideId});

  @override
  ConsumerState<RideTrackingScreen> createState() =>
      _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _repository = RidesRepository();
  dynamic _ride;
  bool _isLoading = true;
  bool _isActioning = false;
  Timer? _pollTimer;

  String? get _effectiveRideId =>
      (widget.rideId == null || widget.rideId!.isEmpty) ? null : widget.rideId;

  @override
  void initState() {
    super.initState();
    if (_effectiveRideId != null) {
      _loadRide();
      // Poll while the ride progresses so driver assignment and status
      // transitions appear without a push channel
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadRide());
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _repository.getRideById(_effectiveRideId!);
      if (mounted && ride != null) {
        setState(() {
          _ride = ride;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this ride?'),
        content: const Text(
            'Cancelling after a driver accepts may incur a cancellation fee.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Ride')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel Ride',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActioning = true);
    try {
      await _repository.cancelRide(_effectiveRideId!, reason: 'Cancelled by customer');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _runDriverAction(Future<dynamic> Function() action,
      {String? successMessage}) async {
    setState(() => _isActioning = true);
    try {
      final updated = await action();
      if (mounted) {
        if (updated?['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride completed!')),
          );
          context.go('/home');
        } else {
          setState(() => _ride = updated);
          if (successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDriver = authState.activeMode == AppUserMode.driver;

    final rideStatus = _ride?['status'] as String?;

    const statusLabels = {
      'requested': 'Looking for a nearby trike...',
      'accepted': 'Your driver accepted! On the way',
      'driver_arriving': 'Your driver has arrived',
      'in_progress': 'Enjoy your ride!',
      'completed': 'Ride completed',
      'cancelled': 'This ride was cancelled',
    };
    final statusText =
        statusLabels[rideStatus] ?? 'Looking for a nearby trike...';

    final driverName =
        _ride?['driverName'] ?? (isDriver ? 'Passenger' : 'Waiting for driver...');
    final plate = _ride?['tricyclePlateNumber'] ?? 'N/A';
    final fare = _ride?['fareEstimate']?.toString() ?? '—';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFECFDF5).withValues(alpha: 0.5),
                    const Color(0xFFECFEFF).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedLinePainter(),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.15,
                    left: MediaQuery.of(context).size.width * 0.25 - 28,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -45 * 3.1415927 / 180,
                        child: const Icon(Icons.navigation,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.35,
                    left: MediaQuery.of(context).size.width * 0.65 - 32,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.electric_rickshaw,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: const AppBackButton(
              iconColor: Colors.black,
              backgroundColor: Colors.white,
              fallbackLocation: '/home',
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5 - 24,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Container(
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$driverName - $plate',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildContactCircle(
                              icon: Icons.phone,
                              color: const Color(0xFF3B82F6),
                              label: 'Call',
                            ),
                            const SizedBox(width: 24),
                            _buildContactCircle(
                              icon: Icons.chat_bubble,
                              color: const Color(0xFF10B981),
                              label: 'Text',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.grey.shade200),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.access_time,
                                            size: 14,
                                            color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('ETA',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '8 min',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.attach_money,
                                            size: 14,
                                            color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Fare',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\u20B1$fare',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isActioning || rideStatus == null
                                ? null
                                : () {
                                    if (isDriver) {
                                      switch (rideStatus) {
                                        case 'accepted':
                                          _runDriverAction(
                                              () => _repository.arrive(_effectiveRideId!),
                                              successMessage: 'Marked as arrived');
                                          break;
                                        case 'driver_arriving':
                                          _runDriverAction(
                                              () => _repository.startRide(_effectiveRideId!),
                                              successMessage: 'Ride started');
                                          break;
                                        case 'in_progress':
                                          _runDriverAction(
                                              () => _repository.completeRide(_effectiveRideId!));
                                          break;
                                      }
                                    } else if (rideStatus == 'completed') {
                                      context.push('/ride/$_effectiveRideId/rating');
                                    } else if (!['cancelled'].contains(rideStatus)) {
                                      _cancelRide();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDriver ||
                                      rideStatus == 'completed'
                                  ? const Color(0xFF2563EB)
                                  : Colors.red.shade600,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor:
                                  const Color(0xFFBFDBFE),
                            ),
                            child: _isActioning
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5),
                                  )
                                : Text(
                                    isDriver
                                        ? switch (rideStatus) {
                                            'accepted' => 'Arrived at Pickup',
                                            'driver_arriving' => 'Start Ride',
                                            'in_progress' => 'Complete Ride',
                                            _ => 'Waiting...',
                                          }
                                        : rideStatus == 'completed'
                                            ? 'Rate your Ride'
                                            : 'Cancel Ride',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        if (!isDriver && rideStatus == 'cancelled') ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.go('/home'),
                            child: Text(
                              'Back to Home',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCircle({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startPoint = Offset(size.width * 0.25, size.height * 0.3);
    final endPoint = Offset(size.width * 0.65, size.height * 0.7);

    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..lineTo(endPoint.dx, endPoint.dy);

    const dashWidth = 10.0;
    const dashSpace = 10.0;
    double distance = 0.0;

    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        final extractPath =
            measurePath.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
