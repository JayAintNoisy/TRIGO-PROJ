import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../data/rides_repository.dart';

class PickDriverScreen extends ConsumerStatefulWidget {
  final String? rideId;
  final String? pickup;
  final String? dropoff;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? municipalityId;
  final int? passengers;

  const PickDriverScreen({
    super.key,
    this.rideId,
    this.pickup,
    this.dropoff,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.municipalityId,
    this.passengers,
  });

  @override
  ConsumerState<PickDriverScreen> createState() => _PickDriverScreenState();
}

class _PickDriverScreenState extends ConsumerState<PickDriverScreen> {
  final _repository = DriversRepository();
  final _ridesRepository = RidesRepository();

  List<dynamic> _drivers = [];
  bool _isLoading = true;
  String? _error;
  String? _bookingDriverId;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    try {
      final drivers = await _repository.getDrivers();
      if (mounted) {
        setState(() {
          // Strictly filter for online and approved drivers only
          _drivers = drivers.where((d) {
            final isOnline = d['isOnline'] == true;
            final isApproved = d['applicationStatus'] == 'approved' ||
                d['applicationStatus'] == null;
            return isOnline && isApproved;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  double _calculateDistanceKm(dynamic driver) {
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.dropoffLat;
    final dLng = widget.dropoffLng;

    if (pLat != null && pLng != null && dLat != null && dLng != null) {
      return haversineKm(pLat, pLng, dLat, dLng);
    }
    return 1.5;
  }

  String _calculateFare(double distanceKm) {
    final fare = 30.0 + (distanceKm * 10.0);
    return '₱${math.max(30.0, fare).toStringAsFixed(0)}';
  }

  String _calculateEta(dynamic driver) {
    final dLat = (driver['currentLat'] as num?)?.toDouble();
    final dLng = (driver['currentLng'] as num?)?.toDouble();
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;

    if (dLat != null && dLng != null && pLat != null && pLng != null) {
      final distToPickup = haversineKm(dLat, dLng, pLat, pLng);
      final minutes = math.max(2, (distToPickup * 3).round());
      return '$minutes min';
    }
    return '3 min';
  }

  Future<void> _chooseDriver(dynamic driver) async {
    final driverId = (driver['id'] ?? driver['userId'] ?? '').toString();
    setState(() => _bookingDriverId = driverId);

    try {
      if (widget.rideId != null && widget.rideId!.isNotEmpty) {
        context.push('/ride/${widget.rideId}/tracking');
        return;
      }

      final municipalityId = widget.municipalityId ??
          driver['municipalityId']?.toString() ??
          '';

      final ride = await _ridesRepository.requestRide(
        municipalityId: municipalityId,
        pickupLat: widget.pickupLat ?? 8.1575,
        pickupLng: widget.pickupLng ?? 125.1278,
        pickupAddress: widget.pickup ?? 'Current Location',
        dropoffLat: widget.dropoffLat ?? 8.1675,
        dropoffLng: widget.dropoffLng ?? 125.1378,
        dropoffAddress: widget.dropoff ?? 'Destination',
      );

      if (mounted) {
        context.push('/ride/${ride['id']}/tracking');
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
      if (mounted) setState(() => _bookingDriverId = null);
    }
  }

  Widget _buildDriverCard(BuildContext context, dynamic driver) {
    final name = driver['userName'] ?? driver['name'] ?? 'Driver';
    final plate = driver['tricyclePlateNumber'] ?? 'N/A';
    final model = driver['tricycleModel'] ?? 'Tricycle';
    final rating = (driver['averageRating'] ?? 5.0).toDouble().toStringAsFixed(1);
    final distanceKm = _calculateDistanceKm(driver);
    final fare = _calculateFare(distanceKm);
    final eta = _calculateEta(driver);
    final driverId = (driver['id'] ?? driver['userId'] ?? '').toString();
    final isBookingThis = _bookingDriverId == driverId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.electric_rickshaw,
                      color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$plate • $model',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 2),
                            Text(
                              rating,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Est. Fare',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        fare,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Est. Arrival',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        eta,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bookingDriverId != null ? null : () => _chooseDriver(driver),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: isBookingThis
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Choose this Driver',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const AppTopBar(title: 'Choose Your Driver'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadDrivers();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _drivers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.electric_rickshaw_outlined,
                                size: 40,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No Drivers Online Nearby',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'There are no active drivers currently online in your area. Please try again in a few moments.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _loadDrivers();
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Refresh Drivers'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: _drivers
                          .map((d) => _buildDriverCard(context, d))
                          .toList(),
                    ),
    );
  }
}
