import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/widgets/app_mode_switch.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _ridesRepository = RidesRepository();
  int _passengerCount = 1;
  bool _isRequesting = false;
  List<dynamic> _municipalities = [];

  @override
  void initState() {
    super.initState();
    _loadMunicipalities();
  }

  Future<void> _loadMunicipalities() async {
    try {
      final municipalities = await _ridesRepository.getMunicipalities();
      if (mounted) setState(() => _municipalities = municipalities);
    } catch (_) {
      // Municipality list is optional for the booking flow
    }
  }

  // Without GPS the pickup starts at the municipality center and the dropoff
  // is offset deterministically from the destination text
  ({double lat, double lng}) _offsetFor(String text, int index) {
    final seed = text.hashCode.abs() % 1000;
    final delta = (seed % 20 - 10) / 1000.0 * (index + 1);
    return (lat: delta, lng: delta);
  }

  Future<void> _findTrike() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    try {
      if (_municipalities.isEmpty) {
        await _loadMunicipalities();
      }
      if (_municipalities.isEmpty) {
        throw Exception('No service areas available yet');
      }
      final municipality = _municipalities.first;
      final centerLat = (municipality['centerLat'] as num).toDouble();
      final centerLng = (municipality['centerLng'] as num).toDouble();

      final pickup =
          _pickupController.text.isNotEmpty ? _pickupController.text : 'Current Location';
      final dropoff = _dropoffController.text.isNotEmpty
          ? _dropoffController.text
          : 'Drop-off Destination';
      final pickupOffset = _offsetFor(pickup, 0);
      final dropoffOffset = _offsetFor(dropoff, 1);

      final ride = await _ridesRepository.requestRide(
        municipalityId: municipality['id'] as String,
        pickupLat: centerLat + pickupOffset.lat,
        pickupLng: centerLng + pickupOffset.lng,
        pickupAddress: pickup,
        dropoffLat: centerLat + dropoffOffset.lat,
        dropoffLng: centerLng + dropoffOffset.lng,
        dropoffAddress: dropoff,
      );

      if (mounted) {
        context.pushNamed('pick-driver', queryParameters: {
          'rideId': ride['id'] as String,
          'pickup': pickup,
          'dropoff': dropoff,
          'passengers': '$_passengerCount',
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  // One-tap passenger/driver switching — only offered to approved drivers
  void _switchMode(AppUserMode mode) {
    if (mode == ref.read(authProvider).activeMode) return;
    ref.read(authProvider.notifier).toggleMode(mode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mode == AppUserMode.driver
            ? 'You\u2019re now driving \u2014 go online to receive requests'
            : 'Switched to passenger mode'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final canDrive = kDebugMode || authState.role == 'driver';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey.shade100,
                    const Color(0xFFECFDF5).withValues(alpha: 0.3),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x333B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.navigation,
                                color: Colors.white, size: 32),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Your Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 12,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu,
                        color: Color(0xFF475569)),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'TRIGO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (canDrive) ...[
                        AppModeSwitch(
                          currentMode: authState.activeMode,
                          onModeChanged: _switchMode,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined,
                                color: Color(0xFF64748B)),
                            onPressed: () =>
                                context.push('/notifications'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45 - 24,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome, ${authState.name ?? 'Rider'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: TextField(
                        controller: _pickupController,
                        decoration: const InputDecoration(
                          hintText: 'Current Location',
                          hintStyle: TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(Icons.my_location,
                              color: Color(0xFF10B981)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 16),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _dropoffController,
                        decoration: const InputDecoration(
                          hintText: 'Drop-off Destination',
                          hintStyle: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(Icons.location_on,
                              color: Color(0xFFEF4444)),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 16),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF)
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('Number of Passengers',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF1E293B))),
                              SizedBox(height: 4),
                              Text(
                                  'Fare will be split among passengers',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9E9E9E))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    if (_passengerCount > 1) {
                                      _passengerCount--;
                                    }
                                  }),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                        child: Text('-',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Colors.grey))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('$_passengerCount',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => setState(
                                      () => _passengerCount++),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                        child: Text('+',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Color(
                                                    0xFF2563EB)))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRequesting ? null : _findTrike,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0xFF2563EB)
                              .withValues(alpha: 0.3),
                        ),
                        child: _isRequesting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Find a Trike',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
