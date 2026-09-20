import 'package:flutter/material.dart';

/// Bottom sheet for Passenger active ride matching screens/html/app/passenger-active-ride.html
///
/// Collapsible like the driver sheet, so a passenger on a small screen can
/// fold it down and see more of the map while the ride is in progress.
class PassengerRideTrackingSheet extends StatefulWidget {
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
  State<PassengerRideTrackingSheet> createState() =>
      _PassengerRideTrackingSheetState();
}

class _PassengerRideTrackingSheetState
    extends State<PassengerRideTrackingSheet> {
  /// Folded by the user to reveal more of the map.
  bool _isCollapsed = false;

  void _toggleCollapsed() => setState(() => _isCollapsed = !_isCollapsed);

  @override
  Widget build(BuildContext context) {
    final statusText = widget.statusText;
    final driverName = widget.driverName;
    final plateNumber = widget.plateNumber;
    final fare = widget.fare;
    final eta = widget.eta;
    final status = widget.status;
    final isActioning = widget.isActioning;
    final onCall = widget.onCall;
    final onText = widget.onText;
    final onCompleteOrCancel = widget.onCompleteOrCancel;

    final isRequested = status == 'requested';
    final isCompleted = status == 'completed';

    // Adapt to the available height and OS font scale so the sheet neither
    // overflows nor crowds out the map on a small device.
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final textScale = media.textScaler.scale(1.0).clamp(0.8, 1.3);
    final isCompact = media.size.height < 680;

    final gap = isCompact ? 8.0 : 14.0;
    final circleSize = isCompact ? 52.0 : 64.0;
    final headlineFontSize = (isCompact ? 17.0 : 20.0) * textScale;
    final valueFontSize = (isCompact ? 20.0 : 26.0) * textScale;
    final actionFontSize = (isCompact ? 15.0 : 16.0) * textScale;

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
      // Cap the sheet so the map keeps the majority of a small screen.
      constraints: BoxConstraints(
        maxHeight: media.size.height * (isCompact ? 0.45 : 0.62),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header doubles as the fold control.
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
                    // Status Headline
                    Text(
                      statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: headlineFontSize,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Driver & Plate Info
                    Text(
                      '$driverName • $plateNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: (isCompact ? 12.0 : 14.0) * textScale,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    SizedBox(height: gap),
                    Divider(color: Colors.grey.shade200, height: 1),
                    SizedBox(height: gap),

                    // Call and Text Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildContactCircle(
                          icon: Icons.phone_rounded,
                          color: const Color(0xFF3B82F6),
                          label: 'Call',
                          size: circleSize,
                          onTap: onCall,
                        ),
                        SizedBox(width: isCompact ? 20 : 28),
                        _buildContactCircle(
                          icon: Icons.chat_bubble_rounded,
                          color: const Color(0xFF10B981),
                          label: 'Text',
                          size: circleSize,
                          onTap: onText,
                        ),
                      ],
                    ),

                    SizedBox(height: gap),
                    Divider(color: Colors.grey.shade200, height: 1),
                    SizedBox(height: gap),

                    // Info Cards: ETA & Fare.
                    // IntrinsicHeight equalises both cards without asking a
                    // scrollable parent for unbounded height (which stretch
                    // cannot do).
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              label: '🕐 ETA',
                              value: eta,
                              background: const Color(0xFFEFF6FF),
                              valueColor: const Color(0xFF1D4ED8),
                              valueFontSize: valueFontSize,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoCard(
                              label: '💲 Fare',
                              value: fare,
                              background: const Color(0xFFECFDF5),
                              valueColor: const Color(0xFF059669),
                              valueFontSize: valueFontSize,
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

          // Pinned footer: the primary action stays visible even when folded.
          Padding(
            padding: EdgeInsets.fromLTRB(24, isCompact ? 6 : 10, 24,
                bottomInset + (isCompact ? 10 : 16)),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActioning ? null : onCompleteOrCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRequested || isCompleted
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
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
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isRequested
                              ? 'Cancel Ride'
                              : isCompleted
                                  ? 'Rate Driver'
                                  : 'Complete Ride',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: actionFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required Color background,
    required Color valueColor,
    required double valueFontSize,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w900,
                color: valueColor,
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
    required double size,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
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
            child: Icon(icon, color: Colors.white, size: size * 0.44),
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
