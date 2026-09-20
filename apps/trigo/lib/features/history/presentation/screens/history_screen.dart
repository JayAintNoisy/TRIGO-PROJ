import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../ride_booking/data/rides_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.rideLoader});

  /// Overrides how rides are fetched. Defaults to the real repository; tests
  /// inject a stub so no network or .env is required.
  final Future<List<dynamic>> Function()? rideLoader;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final RidesRepository _repository = RidesRepository();

  Future<List<dynamic>> _fetchRides() =>
      widget.rideLoader?.call() ?? _repository.getRides();

  List<dynamic> _rides = [];
  bool _isLoading = true;
  String? _error;

  /// The in-flight ride, shown pinned above the list. Null when idle.
  Map? get _activeRide {
    for (final ride in _rides) {
      if (ride is Map &&
          RidesRepository.isActiveStatus(ride['status']?.toString())) {
        return ride;
      }
    }
    return null;
  }

  /// Everything that is not the pinned active ride.
  List<dynamic> get _historyRides {
    final activeId = _activeRide?['id'];
    return _rides
        .where((r) => r is! Map || r['id'] != activeId)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    try {
      final rides = await _fetchRides();
      if (mounted) {
        setState(() {
          _rides = rides;
          _isLoading = false;
          _error = null;
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

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $hour:${dt.minute.toString().padLeft(2, '0')} $suffix';
  }

  ({String label, Color color, Color bg}) _statusStyle(String status) {
    switch (status) {
      case 'completed':
        return (
          label: 'Completed',
          color: const Color(0xFF047857),
          bg: const Color(0xFFD1FAE5)
        );
      case 'cancelled':
        return (
          label: 'Cancelled',
          color: Colors.grey.shade600,
          bg: Colors.grey.shade200
        );
      default:
        // In-flight rides report the actual stage instead of a vague
        // "Active", so the customer knows what is happening right now.
        return (
          label: RidesRepository.activeStatusLabel(status),
          color: const Color(0xFF1D4ED8),
          bg: const Color(0xFFDBEAFE)
        );
    }
  }

  /// Where a ride card should lead when tapped. Completed rides go to rating;
  /// cancelled rides have nothing further to show.
  String? _destinationFor(dynamic ride) {
    if (ride is! Map) return null;
    final id = ride['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final status = ride['status']?.toString();
    if (status == 'completed') return '/ride/$id/rating';
    if (status == 'cancelled') return null;
    return '/ride/$id/tracking';
  }

  void _openRide(dynamic ride) {
    final destination = _destinationFor(ride);
    if (destination == null) return;
    context.push(destination);
  }

  Widget _buildRideCard({
    required BuildContext context,
    required String date,
    required String status,
    required Color statusColor,
    required Color statusBgColor,
    required String pickup,
    required String dropoff,
    required String driverName,
    required String fare,
    required bool isCancelled,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Timeline
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? Colors.grey.shade100
                          : const Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.grey.shade400
                              : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pickup',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400),
                        ),
                        Text(
                          pickup,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? Colors.grey.shade100
                          : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.grey.shade400
                              : const Color(0xFFF87171),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drop-off',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400),
                        ),
                        Text(
                          dropoff,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: Colors.grey.shade100),
              const SizedBox(height: 12),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Fare',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                      Text(
                        fare,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isCancelled
                              ? Colors.grey.shade400
                              : const Color(0xFF059669),
                          decoration:
                              isCancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  if (onTap != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(Icons.chevron_right,
                          color: Colors.grey.shade400, size: 22),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prominent, tappable card for the ride currently in flight. Pinned above
  /// the history list so an in-progress trip is never buried or lost.
  Widget _buildActiveRideCard(Map ride) {
    final status = ride['status']?.toString();
    final style = _statusStyle(status ?? '');
    final fareValue = ride['fareFinal'] ?? ride['fareEstimate'] ?? 0;
    final fare =
        '\u20B1${double.tryParse(fareValue.toString())?.toStringAsFixed(0) ?? '0'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openRide(ride),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ACTIVE RIDE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: Colors.white70,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6EE7B7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          style.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ActiveRouteLine(
                icon: Icons.my_location,
                label: 'Pickup',
                value: ride['pickupAddress'] ?? 'Pickup',
              ),
              const SizedBox(height: 10),
              _ActiveRouteLine(
                icon: Icons.location_on,
                label: 'Drop-off',
                value: ride['dropoffAddress'] ?? 'Drop-off',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fare',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      Text(
                        fare,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openRide(ride),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text(
                      'Continue ride',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1D4ED8),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRide = _activeRide;
    final historyRides = _historyRides;
    // The pinned card is an extra leading item in the same scroll view.
    final leadingCount = activeRide != null ? 1 : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppTopBar(
        title: 'Ride History',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadRides();
            },
          ),
        ],
      ),
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
                          setState(() => _isLoading = true);
                          _loadRides();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _rides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No rides yet',
                              style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRides,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          MediaQuery.of(context).padding.bottom + 80,
                        ),
                        itemCount: leadingCount + historyRides.length,
                        itemBuilder: (context, index) {
                          if (leadingCount == 1 && index == 0) {
                            return _buildActiveRideCard(activeRide!);
                          }
                          final ride = historyRides[index - leadingCount];
                          final status = (ride['status'] ?? '').toString();
                          final style = _statusStyle(status);
                          final isCancelled = status == 'cancelled';
                          final fareValue =
                              ride['fareFinal'] ?? ride['fareEstimate'] ?? 0;
                          return _buildRideCard(
                            context: context,
                            date: _formatDate(ride['createdAt']),
                            status: style.label,
                            statusColor: style.color,
                            statusBgColor: style.bg,
                            pickup: ride['pickupAddress'] ?? 'Pickup',
                            dropoff: ride['dropoffAddress'] ?? 'Drop-off',
                            driverName: ride['driverName'] ?? '—',
                            fare:
                                '\u20B1${double.parse(fareValue.toString()).toStringAsFixed(0)}',
                            isCancelled: isCancelled,
                            onTap: _destinationFor(ride) == null
                                ? null
                                : () => _openRide(ride),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// A pickup/drop-off line inside the pinned active-ride card, styled for the
/// blue gradient background.
class _ActiveRouteLine extends StatelessWidget {
  const _ActiveRouteLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
