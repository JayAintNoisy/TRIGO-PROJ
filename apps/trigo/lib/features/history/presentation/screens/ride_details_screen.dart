import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/utils/rating_window.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payments/data/payments_repository.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/widgets/app_mode_switch.dart';

/// Full detail for one trip: route, fare breakdown and the payment
/// (transaction) it produced.
///
/// Reached from the driver's earnings list and from ride history, so it has to
/// read sensibly for both roles; only the wording and the actions differ.
class RideDetailsScreen extends ConsumerStatefulWidget {
  const RideDetailsScreen({
    super.key,
    required this.rideId,
    this.rideLoader,
    this.paymentLoader,
  });

  final String rideId;

  /// Test seams, mirroring `HistoryScreen.rideLoader`; both default to the real
  /// repositories.
  final Future<dynamic> Function(String rideId)? rideLoader;
  final Future<RidePayment?> Function(String rideId)? paymentLoader;

  @override
  ConsumerState<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends ConsumerState<RideDetailsScreen> {
  // Lazy so injected loaders never construct the Dio client, which reads .env
  // at construction.
  late final RidesRepository _ridesRepository = RidesRepository();
  late final PaymentsRepository _paymentsRepository = PaymentsRepository();

  dynamic _ride;
  RidePayment? _payment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    try {
      final ride = await (widget.rideLoader?.call(widget.rideId) ??
          _ridesRepository.getRideById(widget.rideId));
      if (!mounted) return;

      // A trip only has a transaction once it has been paid out; a missing one
      // is normal, not an error.
      RidePayment? payment;
      if (ride is Map && ride['status'] == 'completed') {
        payment = await (widget.paymentLoader?.call(widget.rideId) ??
            _paymentsRepository.getRidePayment(widget.rideId));
      }
      if (!mounted) return;

      setState(() {
        _ride = ride;
        _payment = payment;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool get _isDriver =>
      ref.read(authProvider).activeMode == AppUserMode.driver;

  double get _fare {
    final value = _ride?['fareFinal'] ?? _ride?['fareEstimate'] ?? 0;
    return (value as num?)?.toDouble() ?? 0;
  }

  String get _statusLabel {
    final status = _ride?['status']?.toString();
    switch (status) {
      case 'requested':
        return 'Finding a driver';
      case 'accepted':
        return 'Driver assigned';
      case 'driver_arriving':
        return 'Driver arriving';
      case 'in_progress':
        return 'Trip in progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color get _statusColor {
    switch (_ride?['status']?.toString()) {
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _formatDateTime(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '—';
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, $hour:$minute $suffix';
  }

  String get _shortId {
    final id = _ride?['id']?.toString() ?? '';
    return id.length >= 8 ? id.substring(0, 8) : id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppTopBar(
        title: 'Trip Details',
        fallbackLocation: _isDriver ? '/driver/earnings' : '/history',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _load(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(context).padding.bottom + 40,
                    ),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildRouteCard(),
                      const SizedBox(height: 16),
                      _buildFareCard(),
                      const SizedBox(height: 16),
                      _buildPaymentCard(),
                      if (_ride?['status']?.toString() == 'completed') ...[
                        const SizedBox(height: 16),
                        _buildRatingCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildPeopleCard(),
                      const SizedBox(height: 20),
                      ..._buildActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _statusLabel,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Trip #$_shortId',
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '\u20B1${_fare.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            _isDriver ? 'Trip earnings' : 'Fare paid',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Text(
            _ride?['status'] == 'completed'
                ? 'Completed ${_formatDateTime(_ride?['completedAt'])}'
                : 'Booked ${_formatDateTime(_ride?['createdAt'])}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard() {
    return _card(
      title: 'Route',
      children: [
        _detailRow(Icons.my_location, 'Pickup',
            _ride?['pickupAddress']?.toString() ?? 'Pickup location'),
        const SizedBox(height: 12),
        _detailRow(Icons.location_on, 'Drop-off',
            _ride?['dropoffAddress']?.toString() ?? 'Drop-off location'),
      ],
    );
  }

  Widget _buildFareCard() {
    final estimate = (_ride?['fareEstimate'] as num?)?.toDouble() ?? 0;
    final finalFare = (_ride?['fareFinal'] as num?)?.toDouble();
    final cancellationFee = (_ride?['cancellationFee'] as num?)?.toDouble() ?? 0;
    final distanceKm = (_ride?['distanceKm'] as num?)?.toDouble() ?? 0;

    return _card(
      title: 'Fare breakdown',
      children: [
        _amountRow('Estimated fare', estimate),
        if (finalFare != null) ...[
          const SizedBox(height: 8),
          _amountRow('Final fare', finalFare, emphasised: true),
        ],
        if (cancellationFee > 0) ...[
          const SizedBox(height: 8),
          _amountRow('Cancellation fee', cancellationFee),
        ],
        const SizedBox(height: 8),
        _amountRow('Distance', null, overrideValue: '${distanceKm.toStringAsFixed(2)} km'),
        if (_ride?['cancellationReason'] != null) ...[
          const SizedBox(height: 12),
          Text(
            'Reason: ${_ride?['cancellationReason']}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentCard() {
    final payment = _payment;

    return _card(
      title: 'Transaction',
      children: [
        if (payment == null)
          Text(
            _ride?['status'] == 'completed'
                ? 'No payment record for this trip yet.'
                : 'A transaction is recorded when the trip is completed.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.grey.shade500,
            ),
          )
        else ...[
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PaymentMethods.byId(payment.method).background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PaymentMethods.byId(payment.method).icon,
                  size: 20,
                  color: PaymentMethods.byId(payment.method).color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PaymentMethods.labelFor(payment.method),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_paymentStatusLabel(payment.status)} · ${_formatDateTime(payment.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _isDriver ? 'Received' : 'Sent',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade500),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '\u20B1${payment.amount.toStringAsFixed(2)}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _paymentStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Paid';
      case 'refunded':
        return 'Refunded';
      default:
        return 'Pending';
    }
  }

  /// What the passenger thought of the trip, and — while the edit window is
  /// open — a way to change it. Showing the stored rating here is what stops
  /// the app from asking a passenger to rate the same trip twice.
  Widget _buildRatingCard() {
    final bool isDriver = _isDriver;
    final dynamic ride = _ride;
    final int? rating = ride is Map ? RidesRepository.ratingOf(ride) : null;
    final comment = ride is Map ? ride['ratingComment']?.toString() : null;
    final ratedAt =
        ride is Map ? DateTime.tryParse(ride['ratedAt']?.toString() ?? '') : null;
    final completedAt = ride is Map
        ? DateTime.tryParse(ride['completedAt']?.toString() ?? '')
        : null;

    if (rating == null) {
      return _card(
        title: isDriver ? 'Passenger rating' : 'Your rating',
        children: [
          Text(
            isDriver
                ? 'Your passenger has not rated this trip.'
                : 'You have not rated this trip yet.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Colors.grey.shade500,
            ),
          ),
          if (!isDriver) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/ride/${widget.rideId}/rating'),
                icon: const Icon(Icons.star_outline_rounded, size: 18),
                label: const Text('Rate your driver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final editable = !isDriver && isRatingEditable(completedAt);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 22,
                color: i < rating
                    ? const Color(0xFFF59E0B)
                    : Colors.grey.shade300,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$rating out of 5',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            comment,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF334155),
            ),
          ),
        ],
        if (ratedAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'Rated ${_formatDateTime(ratedAt)}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
        ],
        if (!isDriver) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                editable ? Icons.edit_outlined : Icons.lock_outline,
                size: 16,
                color: editable
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  editable
                      ? 'Tap to change your rating'
                      : 'Ratings cannot be changed after '
                          '${ratingEditWindowLabel()}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: editable ? FontWeight.w600 : FontWeight.normal,
                    color: editable
                        ? const Color(0xFF2563EB)
                        : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return _card(
      title: isDriver ? 'Passenger rating' : 'Your rating',
      children: [
        if (editable)
          InkWell(
            onTap: () => context.push('/ride/${widget.rideId}/rating?edit=1'),
            child: content,
          )
        else
          content,
      ],
    );
  }

  Widget _buildPeopleCard() {
    final bool isDriver = _isDriver;
    final dynamic ride = _ride;
    // Plain indexing behind an explicit null check: `ride?['x']` inside a
    // conditional branch is ambiguous with a conditional list literal.
    final driverName =
        ride == null ? 'Driver' : (ride['driverName']?.toString() ?? 'Driver');
    final passengerName = ride == null
        ? 'Passenger'
        : (ride['customerName']?.toString() ?? 'Passenger');
    final counterpartName = isDriver ? passengerName : driverName;
    final plate =
        ride == null ? null : ride['tricyclePlateNumber']?.toString();

    return _card(
      title: isDriver ? 'Passenger' : 'Driver',
      children: [
        _detailRow(
          isDriver ? Icons.person_outline : Icons.electric_rickshaw,
          isDriver ? 'Passenger' : 'Driver',
          counterpartName,
        ),
        if (!isDriver && plate != null && plate.isNotEmpty) ...[
          const SizedBox(height: 12),
          _detailRow(Icons.confirmation_number_outlined, 'Plate', plate),
        ],
        const SizedBox(height: 12),
        _detailRow(
          Icons.schedule,
          'Booked',
          _formatDateTime(_ride?['createdAt']),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    final status = _ride?['status']?.toString();
    final actions = <Widget>[];

    if (RidesRepository.isActiveStatus(status)) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => context.push('/ride/${widget.rideId}/tracking'),
          icon: const Icon(Icons.navigation_rounded, size: 18),
          label: const Text('Track this ride'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      );
    }
    // Rating for a finished trip lives in the rating card above, so there is
    // exactly one place the app asks for it.

    return actions;
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountRow(
    String label,
    double? amount, {
    bool emphasised = false,
    String? overrideValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: emphasised ? const Color(0xFF0F172A) : Colors.grey.shade600,
              fontWeight: emphasised ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              overrideValue ?? '\u20B1${(amount ?? 0).toStringAsFixed(2)}',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: emphasised ? FontWeight.w900 : FontWeight.w600,
                color:
                    emphasised ? const Color(0xFF059669) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
