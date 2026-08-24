import 'package:flutter/material.dart';

/// Bottom sheet for Passenger active ride matching screens/html/app/passenger-active-ride.html
class PassengerRideTrackingSheet extends StatelessWidget {
  const PassengerRideTrackingSheet({
    super.key,
    required this.statusText,
    required this.driverName,
    required this.plateNumber,
    required this.fare,
    required this.eta,
    required this.status,
    required this.isActioning,
    required this.onCall,
    required this.onText,
    required this.onCompleteOrCancel,
  });

  final String statusText;
  final String driverName;
  final String plateNumber;
  final String fare;
  final String eta;
  final String status;
  final bool isActioning;
  final VoidCallback onCall;
  final VoidCallback onText;
  final VoidCallback onCompleteOrCancel;

  @override
  Widget build(BuildContext context) {
    final isRequested = status == 'requested';
    final isCompleted = status == 'completed';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Status Headline
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Driver & Plate Info
          Text(
            '$driverName • $plateNumber',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),

          // Call and Text Actions (72x72 Circular Buttons matching HTML design)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildContactCircle(
                icon: Icons.phone_rounded,
                color: const Color(0xFF3B82F6),
                label: 'Call',
                onTap: onCall,
              ),
              const SizedBox(width: 28),
              _buildContactCircle(
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFF10B981),
                label: 'Text',
                onTap: onText,
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 14),

          // Info Cards: ETA & Fare (Matching HTML design)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🕐 ETA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eta,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💲 Fare',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fare,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Bottom Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActioning ? null : onCompleteOrCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRequested || isCompleted
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: isActioning
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isRequested
                          ? 'Cancel Ride'
                          : isCompleted
                              ? 'Rate Driver'
                              : 'Complete Ride',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCircle({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
