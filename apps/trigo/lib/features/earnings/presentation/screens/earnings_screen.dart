import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../ride_booking/data/rides_repository.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  final _repository = RidesRepository();
  List<dynamic> _completedRides = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    try {
      // Driver-scoped: the backend filters rides by the assigned driver
      final rides = await _repository.getRides(status: 'completed');
      if (mounted) {
        setState(() {
          _completedRides = rides;
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

  double get _todayEarnings {
    final now = DateTime.now();
    return _completedRides.fold(0.0, (sum, ride) {
      final completedAt =
          DateTime.tryParse(ride['completedAt']?.toString() ?? '');
      final isToday = completedAt != null &&
          completedAt.year == now.year &&
          completedAt.month == now.month &&
          completedAt.day == now.day;
      final fare = (ride['fareFinal'] ?? ride['fareEstimate'] ?? 0).toDouble();
      return sum + (isToday ? fare : 0);
    });
  }

  int get _todayTrips {
    final now = DateTime.now();
    return _completedRides.where((ride) {
      final completedAt =
          DateTime.tryParse(ride['completedAt']?.toString() ?? '');
      return completedAt != null &&
          completedAt.year == now.year &&
          completedAt.month == now.month &&
          completedAt.day == now.day;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Driver Earnings',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadEarnings();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!,
                            style:
                                const TextStyle(color: Color(0xFFDC2626))),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _loadEarnings();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppCard(
                          backgroundColor: const Color(0xFF059669),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Today\'s Gross Earnings',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\u20B1${_todayEarnings.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStat('Trips Today', '$_todayTrips completed'),
                                  _buildStat('All-Time Trips', '${_completedRides.length}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Recent Completed Trips',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          child: _completedRides.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: Text('No completed trips yet')),
                                )
                              : Column(
                                  children: [
                                    for (int i = 0;
                                        i < _completedRides.take(5).length;
                                        i++) ...[
                                      if (i > 0) const Divider(),
                                      Builder(builder: (context) {
                                        final ride = _completedRides[i];
                                        return _buildTripRow(
                                          '#${ride['id']?.toString().substring(0, 8) ?? '—'}',
                                          '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['dropoffAddress'] ?? 'Drop-off'}',
                                          '\u20B1${((ride['fareFinal'] ?? ride['fareEstimate'] ?? 0) as num).toStringAsFixed(2)}',
                                          _formatTime(ride['completedAt']),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatTime(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '';
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $suffix';
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTripRow(String title, String route, String fare, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(route, style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fare, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
