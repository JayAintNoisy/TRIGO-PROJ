import 'package:flutter/material.dart';

/// Bottom sheet for Driver active ride matching screens/html/app/driver-active-ride.html
///
/// The sheet is collapsible: on a small screen it must not crowd out the map,
/// so the header can be tapped to fold the body down to a compact summary.
class DriverRideTrackingSheet extends StatefulWidget {
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
  State<DriverRideTrackingSheet> createState() =>
      _DriverRideTrackingSheetState();
}

class _DriverRideTrackingSheetState extends State<DriverRideTrackingSheet> {
  /// Folded by the user to reveal more of the map.
  bool _isCollapsed = false;

  void _toggleCollapsed() => setState(() => _isCollapsed = !_isCollapsed);

  @override
  Widget build(BuildContext context) {
    final passengerName = widget.passengerName;
    final passengerCount = widget.passengerCount;
    final pickupAddress = widget.pickupAddress;
    final dropoffAddress = widget.dropoffAddress;
    final fare = widget.fare;
    final status = widget.status;
    final isActioning = widget.isActioning;
    final onCall = widget.onCall;
    final onText = widget.onText;
    final onStepAction = widget.onStepAction;

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

    // Adapt spacing and type to the available height and the OS font scale so
    // the sheet never overflows on a short screen or with large text.
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final textScale = media.textScaler.scale(1.0).clamp(0.8, 1.3);
    final isCompact = media.size.height < 680;

    final gap = isCompact ? 10.0 : 14.0;
    final avatarSize = isCompact ? 44.0 : 52.0;
    final fareFontSize = (isCompact ? 26.0 : 32.0) * textScale;
    final nameFontSize = (isCompact ? 15.0 : 17.0) * textScale;
    final subFontSize = (isCompact ? 11.0 : 12.0) * textScale;
    final actionFontSize = (isCompact ? 15.0 : 17.0) * textScale;

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
      // Cap the sheet so the map stays the majority of the view on a small
      // device; the body scrolls while the progression button stays pinned.
      constraints: BoxConstraints(
        maxHeight: media.size.height * (isCompact ? 0.45 : 0.62),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tapping the header folds the sheet down to reveal the map.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleCollapsed,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, isCompact ? 10 : 14, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isCollapsed ? 'Show details' : 'Hide details',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Icon(
                        _isCollapsed
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!_isCollapsed)
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, isCompact ? 6 : 10, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Passenger Info Card (Matching HTML design)
                    Container(
                      padding: EdgeInsets.all(isCompact ? 12 : 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // slate-100
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.person,
                                color: Colors.white, size: avatarSize * 0.54),
                          ),
                          SizedBox(width: isCompact ? 10 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  passengerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$passengerCount passenger${passengerCount > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: subFontSize,
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
                                    fontSize: subFontSize,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),

                    // Action Buttons: Call & Text (Matching HTML design)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onCall,
                            icon: const Icon(Icons.phone, size: 18),
                            label: Text('Call',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: actionFontSize - 2)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: isCompact ? 12 : 14),
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
                            label: Text('Text',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: actionFontSize - 2)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  vertical: isCompact ? 12 : 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: gap),

                    // Current Fare Card (Matching HTML design)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: isCompact ? 10 : 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Current Fare',
                            style: TextStyle(
                              fontSize: subFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              fare,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: fareFontSize,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap),
                  ],
                ),
              ),
            ),

          // Pinned footer: the progression action stays visible no matter how
          // much the body above has to scroll.
          Padding(
            padding: EdgeInsets.fromLTRB(24, isCompact ? 6 : 10, 24,
                bottomInset + (isCompact ? 10 : 16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isActioning ? null : onStepAction,
                    icon: Icon(buttonIcon, size: isCompact ? 18 : 22),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        buttonText,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: actionFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: buttonColor,
                      padding:
                          EdgeInsets.symmetric(vertical: isCompact ? 10 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 4 : 8),

                // Step Progress Text. Capped to two lines and allowed to
                // shrink, so a large font scale cannot push the footer past
                // the sheet's height budget.
                Text(
                  stepText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.linear(textScale.clamp(0.8, 1.1)),
                  style: TextStyle(
                    fontSize: subFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
