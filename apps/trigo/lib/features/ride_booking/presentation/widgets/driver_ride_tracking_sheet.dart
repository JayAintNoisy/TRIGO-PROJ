import 'package:flutter/material.dart';

/// Bottom sheet for Driver active ride matching screens/html/app/driver-active-ride.html
class DriverRideTrackingSheet extends StatelessWidget {
  const DriverRideTrackingSheet({
    super.key,
    required this.passengerName,
    required this.passengerCount,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.fare,
    required this.status,
    required this.isActioning,
    required this.onCall,
    required this.onText,
    required this.onStepAction,
  });

  final String passengerName;
  final int passengerCount;
  final String pickupAddress;
  final String dropoffAddress;
  final String fare;
  final String status;
  final bool isActioning;
  final VoidCallback onCall;
  final VoidCallback onText;
  final VoidCallback onStepAction;

  @override
  Widget build(BuildContext context) {
    // Determine current progression step
    String buttonText;
    IconData buttonIcon;
    Color buttonColor;
    String stepText;

    if (status == 'accepted') {
      buttonText = 'Arrived';
      buttonIcon = Icons.location_on_rounded;
      buttonColor = const Color(0xFF2563EB);
      stepText = 'Step 1 of 3: Arriving at pickup location';
    } else if (status == 'driver_arriving') {
      buttonText = 'Start Ride';
      buttonIcon = Icons.navigation_rounded;
      buttonColor = const Color(0xFF10B981);
      stepText = 'Step 2 of 3: Passenger boarded, starting trip';
    } else {
      buttonText = 'Complete Ride';
      buttonIcon = Icons.check_circle_rounded;
      buttonColor = const Color(0xFF2563EB);
      stepText = 'Step 3 of 3: Dropping off passenger at destination';
    }

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

          // Passenger Info Card (Matching HTML design)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // slate-100
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$passengerCount passenger${passengerCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status == 'in_progress'
                            ? 'Drop-off: $dropoffAddress'
                            : 'Pickup: $pickupAddress',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Call & Text (Matching HTML design)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onText,
                  icon: const Icon(Icons.chat_bubble, size: 18),
                  label: const Text('Text', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current Fare Card (Matching HTML design)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              children: [
                const Text(
                  'Current Fare',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fare,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Progression Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isActioning ? null : onStepAction,
              icon: Icon(buttonIcon, size: 22),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Step Progress Text
          Text(
            stepText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
