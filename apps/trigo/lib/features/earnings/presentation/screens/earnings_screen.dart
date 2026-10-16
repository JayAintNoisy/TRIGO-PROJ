import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../core/router/branch_visibility.dart';
import '../../../../shared/utils/app_time.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../ride_booking/data/rides_repository.dart';

/// Driver earnings: today's totals plus the most recent completed trips, each
/// of which opens its own trip detail and transaction.
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key, this.rideLoader});

  /// Test seam, mirroring `HistoryScreen.rideLoader`; defaults to the real
  /// repository so tests need no network or .env.
  final Future<List<dynamic>> Function({String? status})? rideLoader;

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  // Lazy so an injected loader never constructs the Dio client (which reads
  // .env at construction) — the same pattern HistoryScreen uses.
  late final RidesRepository _repository = RidesRepository();
  List<dynamic> _completedRides = [];
  bool _isLoading = true;
  String? _error;

  /// How many recent trips the summary card lists.
  static const int _recentTripCount = 5;

  @override
  void initState() {
    super.initState();
    _loadEarnings();
    // Earnings go stale the moment a trip completes while this tab is off
    // screen, so reload whenever the tab becomes visible again.
    activeBranchNotifier.addListener(_onBranchChanged);
  }

  @override
  void dispose() {
    activeBranchNotifier.removeListener(_onBranchChanged);
    super.dispose();
  }

  void _onBranchChanged() {
    if (activeBranchNotifier.value == middleBranchIndex && mounted) {
      _loadEarnings(silent: true);
    }
  }

  Future<List<dynamic>> _fetchRides() =>
      widget.rideLoader?.call(status: 'completed') ??
      _repository.getRides(status: 'completed');

  /// [silent] keeps the current list on screen while refreshing in the
  /// background, which is what a revisit should feel like.
  Future<void> _loadEarnings({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final rides = await _fetchRides();
      if (!mounted) return;
      setState(() {
        // Newest completed trip first: the API orders by booking time, which
        // is not the same thing.
        _completedRides = RidesRepository.sortByCompletedDesc(rides);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _completedRides.isNotEmpty) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  double get _todayEarnings {
    final now = DateTime.now();
    return _completedRides.fold(0.0, (sum, ride) {
      // Compared in the driver's own timezone: a UTC day boundary would land at
      // 8am local for a Philippine driver.
      final isToday = isSameLocalDay(ride['completedAt'], now);
      final fare = (ride['fareFinal'] ?? ride['fareEstimate'] ?? 0).toDouble();
      return sum + (isToday ? fare : 0);
    });
  }

  int get _todayTrips {
    final now = DateTime.now();
    return _completedRides
        .where((ride) => isSameLocalDay(ride['completedAt'], now))
        .length;
  }

  void _openTrip(dynamic ride) {
    final id = ride['id']?.toString();
    if (id == null || id.isEmpty) return;
    context.push('/ride/$id/details');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Driver Earnings',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadEarnings(),
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
                          onPressed: () => _loadEarnings(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadEarnings(silent: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        20.0,
                        20.0,
                        20.0,
                        MediaQuery.of(context).padding.bottom + 80,
                      ),
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
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStat('Trips Today',
                                        '$_todayTrips completed'),
                                    _buildStat('All-Time Trips',
                                        '${_completedRides.length}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Recent Completed Trips',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Newest first — tap a trip for its details and transaction',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppCard(
                            child: _completedRides.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child:
                                            Text('No completed trips yet')),
                                  )
                                : Column(children: _buildRecentTrips()),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  String _formatTime(dynamic raw) => formatClock(parseServerTime(raw), fallback: '');

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// The most recent trips, newest first, separated by dividers.
  List<Widget> _buildRecentTrips() {
    final recent = _completedRides.take(_recentTripCount).toList();
    return [
      for (var i = 0; i < recent.length; i++) ...[
        if (i > 0) const Divider(),
        _buildTripRow(recent[i]),
      ],
    ];
  }

  Widget _buildTripRow(dynamic ride) {
    final id = ride['id']?.toString() ?? '';
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;
    final fare = (ride['fareFinal'] ?? ride['fareEstimate'] ?? 0) as num;
    final completedAt = ride['completedAt'] ?? ride['createdAt'];
    final method = RidesRepository.settledPaymentMethod(ride);

    return InkWell(
      onTap: () => _openTrip(ride),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#$shortId',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    '${ride['pickupAddress'] ?? 'Pickup'} → ${ride['dropoffAddress'] ?? 'Drop-off'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (method != null) ...[
                    const SizedBox(height: 6),
                    // How the passenger paid, so the driver can reconcile a
                    // trip without opening it.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PaymentMethods.byId(method).icon,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          PaymentMethods.labelFor(method),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20B1${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981)),
                ),
                Text(_formatTime(completedAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
