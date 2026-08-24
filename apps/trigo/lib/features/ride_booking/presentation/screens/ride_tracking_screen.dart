import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../widgets/ride_tracking_map_view.dart';
import '../widgets/passenger_ride_tracking_sheet.dart';
import '../widgets/driver_ride_tracking_sheet.dart';

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
      // Poll while the ride progresses so driver assignment, live coordinates,
      // and status transitions update in real time
      _pollTimer =
          Timer.periodic(const Duration(seconds: 4), (_) => _loadRide());
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

        // Automatically navigate to rating when completed
        if (ride['status'] == 'completed') {
          final authState = ref.read(authProvider);
          final isDriver = authState.activeMode == AppUserMode.driver;
          if (!isDriver) {
            _pollTimer?.cancel();
            context.push('/ride/${widget.rideId}/rating');
          }
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel this ride?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Are you sure you want to cancel your ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActioning = true);
    try {
      await _repository.cancelRide(_effectiveRideId!,
          reason: 'Cancelled by customer');
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
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _handleDriverStepAction() async {
    final currentStatus = _ride?['status'] as String? ?? 'accepted';
    setState(() => _isActioning = true);

    try {
      if (currentStatus == 'accepted') {
        final updated = await _repository.arrive(_effectiveRideId!);
        if (mounted) setState(() => _ride = updated);
      } else if (currentStatus == 'driver_arriving') {
        final updated = await _repository.startRide(_effectiveRideId!);
        if (mounted) setState(() => _ride = updated);
      } else if (currentStatus == 'in_progress') {
        final updated = await _repository.completeRide(_effectiveRideId!);
        if (mounted) {
          setState(() => _ride = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride completed successfully!')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _showContactModal({
    required String name,
    required String phone,
    required bool isCall,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(modalContext).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Icon(
                isCall ? Icons.phone_forwarded : Icons.message,
                color: isCall ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                isCall ? 'Call $name' : 'Message $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                phone.isNotEmpty ? phone : 'Phone number not available',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Number'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Dismiss'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDriver = authState.activeMode == AppUserMode.driver;

    final rideStatus = (_ride?['status'] as String?) ?? 'requested';
    final pLat = (_ride?['pickupLat'] as num?)?.toDouble();
    final pLng = (_ride?['pickupLng'] as num?)?.toDouble();
    final dLat = (_ride?['dropoffLat'] as num?)?.toDouble();
    final dLng = (_ride?['dropoffLng'] as num?)?.toDouble();
    final drvLat = (_ride?['driverLat'] as num?)?.toDouble();
    final drvLng = (_ride?['driverLng'] as num?)?.toDouble();
    final distanceKm = (_ride?['distanceKm'] as num?)?.toDouble() ?? 1.2;

    final fareEstimate = (_ride?['fareEstimate'] as num?)?.toDouble() ?? 45.0;
    final fareText = '₱${fareEstimate.toStringAsFixed(0)}';

    final passengerName =
        _ride?['customerName'] ?? _ride?['userName'] ?? 'Passenger';
    final passengerPhone =
        _ride?['customerPhone'] ?? _ride?['userPhone'] ?? '';
    final driverName = _ride?['driverName'] ?? 'Waiting for driver...';
    final driverPhone = _ride?['driverPhone'] ?? '';
    final plate = _ride?['tricyclePlateNumber'] ?? 'ABC-1234';
    final pickupAddress = _ride?['pickupAddress'] ?? 'Pickup Location';
    final dropoffAddress = _ride?['dropoffAddress'] ?? 'Drop-off Destination';

    String statusHeadline;
    if (rideStatus == 'requested') {
      statusHeadline = 'Finding your nearby driver...';
    } else if (rideStatus == 'accepted') {
      statusHeadline = 'Your driver is on the way';
    } else if (rideStatus == 'driver_arriving') {
      statusHeadline = 'Your driver has arrived!';
    } else if (rideStatus == 'in_progress') {
      statusHeadline = 'Enjoy your ride!';
    } else if (rideStatus == 'completed') {
      statusHeadline = 'Ride completed';
    } else {
      statusHeadline = 'Ride in progress';
    }

    final etaMinutes = (distanceKm * 2.5).clamp(2, 20).round();
    final etaText = '$etaMinutes min';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full-screen Mapbox Map Viewer
          Positioned.fill(
            child: RideTrackingMapView(
              isDriver: isDriver,
              pickupLat: pLat,
              pickupLng: pLng,
              dropoffLat: dLat,
              dropoffLng: dLng,
              driverLat: drvLat,
              driverLng: drvLng,
              distanceKm: distanceKm,
              bottomOffset: 340,
            ),
          ),

          // 2. Floating Back Button
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
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          // 3. Active Ride Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _isLoading
                ? Container(
                    padding: const EdgeInsets.all(40),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : isDriver
                    ? DriverRideTrackingSheet(
                        passengerName: passengerName,
                        passengerCount:
                            (_ride?['passengers'] as num?)?.toInt() ?? 1,
                        pickupAddress: pickupAddress,
                        dropoffAddress: dropoffAddress,
                        fare: fareText,
                        status: rideStatus,
                        isActioning: _isActioning,
                        onCall: () => _showContactModal(
                          name: passengerName,
                          phone: passengerPhone,
                          isCall: true,
                        ),
                        onText: () => _showContactModal(
                          name: passengerName,
                          phone: passengerPhone,
                          isCall: false,
                        ),
                        onStepAction: _handleDriverStepAction,
                      )
                    : PassengerRideTrackingSheet(
                        statusText: statusHeadline,
                        driverName: driverName,
                        plateNumber: plate,
                        fare: fareText,
                        eta: etaText,
                        status: rideStatus,
                        isActioning: _isActioning,
                        onCall: () => _showContactModal(
                          name: driverName,
                          phone: driverPhone,
                          isCall: true,
                        ),
                        onText: () => _showContactModal(
                          name: driverName,
                          phone: driverPhone,
                          isCall: false,
                        ),
                        onCompleteOrCancel: () {
                          if (rideStatus == 'requested' ||
                              rideStatus == 'accepted') {
                            _cancelRide();
                          } else {
                            context.push('/ride/${widget.rideId}/rating');
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
