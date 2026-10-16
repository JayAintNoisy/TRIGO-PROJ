import 'package:flutter/material.dart';

import '../../../ride_booking/data/rides_repository.dart';

/// Prominent card for the ride a user is currently in, shown on the home
/// screen so leaving the tracking screen never strands an active trip.
///
/// Used by both roles: a driver resumes their assigned trip, a passenger
/// resumes the ride they booked. While this card is visible the home screen's
/// idle controls (booking sheet, waiting-for-passengers status) are hidden.
class ActiveRideCard extends StatelessWidget {
  const ActiveRideCard({
    super.key,
    required this.ride,
    required this.isDriver,
    required this.onContinue,
  });

  final Map ride;
  final bool isDriver;
  final VoidCallback onContinue;

  /// Driver-facing wording for the ride stage. The passenger wording comes
  /// from [RidesRepository.activeStatusLabel], which is written for them.
  String get _statusLabel {
    final status = ride['status']?.toString();
    if (!isDriver) return RidesRepository.activeStatusLabel(status);

    switch (status) {
      case 'accepted':
        return 'Heading to pickup';
      case 'driver_arriving':
        return 'Waiting at pickup';
      case 'in_progress':
        return 'Trip in progress';
      default:
        return 'Active trip';
    }
  }

  String get _title => isDriver ? 'CURRENT TRIP' : 'ACTIVE RIDE';

  String get _actionLabel => isDriver ? 'Resume trip' : 'Continue ride';

  @override
  Widget build(BuildContext context) {
    final fareValue = ride['fareFinal'] ?? ride['fareEstimate'] ?? 0;
    final fare = double.tryParse(fareValue.toString());
    final fareText =
        '\u20B1${fare == null ? '0' : fare.toStringAsFixed(0)}';

    final colors = isDriver
        ? const [Color(0xFF059669), Color(0xFF047857)]
        : const [Color(0xFF2563EB), Color(0xFF1D4ED8)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onContinue,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Colors.white70,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6EE7B7),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RouteLine(
                  icon: Icons.my_location,
                  label: 'Pickup',
                  value: ride['pickupAddress']?.toString() ?? 'Pickup',
                ),
                const SizedBox(height: 8),
                _RouteLine(
                  icon: Icons.location_on,
                  label: 'Drop-off',
                  value: ride['dropoffAddress']?.toString() ?? 'Drop-off',
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fare',
                          style: TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                        Text(
                          fareText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: Text(
                        _actionLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colors.last,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
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
        Icon(icon, size: 17, color: Colors.white70),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: Colors.white70),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
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
