import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../ride_booking/presentation/widgets/incoming_request_modal.dart';
import '../widgets/driver_map_view.dart';
import '../widgets/driver_status_card.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() =>
      _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _ridesRepository = RidesRepository();
  final _driversRepository = DriversRepository();
  bool _isOnline = true;
  bool _isToggling = false;
  Timer? _requestTimer;
  Timer? _locationTimer;
  final Set<String> _shownRequestIds = {};
  int _pendingRequests = 0;
  List<dynamic> _municipalities = [];
  String? _municipalityId;
  geo.Position? _currentPosition;
  List<dynamic> _availableRides = const [];

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
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final results = await Future.wait([
        _driversRepository.getMe().catchError((_) => null),
        _ridesRepository.getMunicipalities(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map?;
      setState(() {
        _isOnline = profile?['isOnline'] ?? false;
        _municipalityId = profile?['municipalityId'] as String?;
        _municipalities = results[1] as List<dynamic>;
      });
      if (_isOnline) _startLocationUpdates();
    } catch (_) {
      // Ignored; retried on reconnect
    }
  }

  Future<void> _pollRequests() async {
    if (!_isOnline || _isToggling || !mounted) return;
    try {
      final rides = await _ridesRepository.getAvailableRides();
      if (!mounted) return;
      setState(() {
        _pendingRequests = rides.length;
        _availableRides = rides;
      });
      final fresh =
          rides.where((r) => !_shownRequestIds.contains(r['id'])).toList();
      if (fresh.isNotEmpty) {
        final ride = fresh.first as Map;
        _shownRequestIds.add(ride['id'] as String);
        _showRequestModal(ride);
      }
    } catch (_) {
      // Polling failures are non-fatal; retried on next tick
    }
  }

  void _showRequestModal(Map ride) {
    IncomingRequestModal.show(context, ride, () async {
      try {
        await _ridesRepository.acceptRide(ride['id'] as String);
        if (mounted) context.push('/ride/${ride['id']}/tracking');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      }
    });
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refreshLocation());
    _refreshLocation();
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  /// Reads GPS and publishes the fix so /drivers/online and the admin live
  /// tracking map reflect this driver's position.
  Future<void> _refreshLocation() async {
    if (!_isOnline || !mounted || _isToggling) return;
    final pos = await _getCurrentPosition();
    if (!mounted || pos == null || !_isOnline) return;
    setState(() => _currentPosition = pos);
    try {
      await _driversRepository.broadcastLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
      );
    } catch (_) {
      // Broadcast failures are non-fatal; retried on next tick
    }
  }

  Future<geo.Position?> _getCurrentPosition() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever ||
          !await geo.Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
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
      if (_isOnline) {
        _pollRequests();
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
        if (mounted) setState(() => _currentPosition = null);
      }
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
    super.build(context);
    final isCompact = MediaQuery.of(context).size.height < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: DriverMapView(
              municipalities: _municipalities,
              municipalityId: _municipalityId,
              availableRides: _availableRides,
              isOnline: _isOnline,
              currentPosition: _currentPosition,
              onPickupTapped: _showRequestModal,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
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
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + (isCompact ? 42 : 46),
            left: 14,
            right: 14,
            child: DriverStatusCard(
              isOnline: _isOnline,
              isToggling: _isToggling,
              pendingRequests: _pendingRequests,
              onToggleOnline: _toggleOnline,
            ),
          ),
        ],
      ),
    );
  }
}
