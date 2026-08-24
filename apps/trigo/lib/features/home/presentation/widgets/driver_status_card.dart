import 'package:flutter/material.dart';

/// Unified bottom status card for the driver home screen: displays current
/// online/offline state, pending ride request counts, active/offline pill,
/// and the Go Online / Go Offline action button.
class DriverStatusCard extends StatelessWidget {
  const DriverStatusCard({
    super.key,
    required this.isOnline,
    required this.isToggling,
    required this.pendingRequests,
    required this.onToggleOnline,
  });

  final bool isOnline;
  final bool isToggling;
  final int pendingRequests;
  final VoidCallback? onToggleOnline;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 600;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFFD1FAE5)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOnline
                      ? Icons.radar
                      : Icons.pause_circle_outline,
                  color: isOnline
                      ? const Color(0xFF059669)
                      : Colors.grey.shade500,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline
                          ? (pendingRequests > 0
                              ? '$pendingRequests ride request(s) nearby!'
                              : 'Waiting for passengers...')
                          : 'You are currently offline',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline
                          ? 'Nearby passengers visible on map'
                          : 'Go online to start receiving ride requests',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isOnline
                            ? const Color(0xFF059669)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFFECFDF5)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFFA7F3D0)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Active' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline
                            ? const Color(0xFF059669)
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isToggling ? null : onToggleOnline,
              style: ElevatedButton.styleFrom(
                backgroundColor: isOnline
                    ? const Color(0xFF10B981)
                    : const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: Icon(
                isOnline ? Icons.close : Icons.power_settings_new,
                size: 20,
              ),
              label: isToggling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isOnline ? 'Go Offline' : 'Go Online',
                      style: const TextStyle(
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
}
