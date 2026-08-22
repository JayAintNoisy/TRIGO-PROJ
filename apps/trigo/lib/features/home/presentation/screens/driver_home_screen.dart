import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../ride_booking/presentation/widgets/incoming_request_modal.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() =>
      _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final _ridesRepository = RidesRepository();
  final _driversRepository = DriversRepository();
  bool _isOnline = true;
  bool _isToggling = false;
  Timer? _requestTimer;
  final Set<String> _shownRequestIds = {};
  int _pendingRequests = 0;

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
    // Poll for open ride requests in the driver's municipality
    _requestTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollRequests());
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final profile = await _driversRepository.getMe();
      if (mounted && profile != null) {
        setState(() => _isOnline = profile['isOnline'] ?? false);
      }
    } catch (_) {}
  }

  Future<void> _pollRequests() async {
    if (!_isOnline || _isToggling || !mounted) return;
    try {
      final rides = await _ridesRepository.getAvailableRides();
      if (!mounted) return;
      setState(() => _pendingRequests = rides.length);
      final fresh = rides.where((r) => !_shownRequestIds.contains(r['id'])).toList();
      if (fresh.isNotEmpty) {
        final ride = fresh.first;
        _shownRequestIds.add(ride['id']);
        await IncomingRequestModal.show(context, ride, () async {
          try {
            await _ridesRepository.acceptRide(ride['id']);
            if (mounted) context.push('/ride/${ride['id']}/tracking');
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        e.toString().replaceFirst('Exception: ', ''))),
              );
            }
          }
        });
      }
    } catch (_) {
      // Polling failures are non-fatal; retried on next tick
    }
  }

  Future<void> _toggleOnline() async {
    setState(() => _isToggling = true);
    try {
      final result =
          await _driversRepository.toggleOnlineStatus(!_isOnline);
      if (mounted) {
        setState(() {
          _isOnline = result['isOnline'] ?? !_isOnline;
          _isToggling = false;
        });
      }
      if (_isOnline) _pollRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _isToggling = false);
      }
    }
  }

  // One-tap passenger/driver switching lives on the Profile page now.

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final name = authState.name ?? 'Driver';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFECFDF5).withValues(alpha: 0.5),
                    const Color(0xFFF0FDF4).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBBF24),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFBBF24)
                                  .withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.electric_rickshaw,
                              color: Colors.white, size: 40),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF34D399)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_none,
                        color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 88,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isOnline
                                ? Icons.flight_takeoff
                                : Icons.flight_land,
                            color: _isOnline
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isOnline
                                ? 'You are Online'
                                : 'You are Offline',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isOnline ? 'Active' : 'Offline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _isOnline
                                  ? const Color(0xFF059669)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isToggling ? null : _toggleOnline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(_isOnline
                          ? Icons.close
                          : Icons.power_settings_new),
                      label: _isToggling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5),
                            )
                          : Text(
                              _isOnline
                                  ? 'Go Offline'
                                  : 'Go Online',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _isOnline
                              ? const Color(0xFFD1FAE5)
                              : Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isOnline
                              ? Icons.radar
                              : Icons.pause_circle_outline,
                          color: _isOnline
                              ? const Color(0xFF059669)
                              : Colors.grey.shade500,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline
                                  ? (_pendingRequests > 0
                                      ? '$_pendingRequests ride request(s) nearby!'
                                      : 'Waiting for passengers...')
                                  : 'You are currently offline',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isOnline
                                  ? 'Nearby passengers visible on map'
                                  : 'Go online to start receiving ride requests',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _isOnline
                                    ? const Color(0xFF059669)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
