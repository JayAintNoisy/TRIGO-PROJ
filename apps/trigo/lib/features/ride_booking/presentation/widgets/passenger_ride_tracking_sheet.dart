import 'package:flutter/material.dart';

import '../../../../core/constants/payment_methods.dart';

/// Bottom sheet for Passenger active ride matching screens/html/app/passenger-active-ride.html
///
/// Collapsible like the driver sheet, so a passenger on a small screen can
/// fold it down and see more of the map while the ride is in progress.
///
/// The passenger only ever acts before the trip (cancel) or after it (rate).
/// Once the driver starts the ride the trip lifecycle belongs to the driver, so
/// no complete-ride action is offered here.
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
    required this.onCancelRide,
    required this.onRateDriver,
    this.onViewReceipt,
    this.existingRating,
    this.driverPaymentMethods = const [],
    this.selectedPaymentMethod,
    this.onChoosePaymentMethod,
    this.onMessage,
    this.hasDriver = true,
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

  /// Cancels a ride that has not started yet.
  final VoidCallback onCancelRide;

  /// Opens the rating screen for a finished ride.
  final VoidCallback onRateDriver;

  /// Opens the receipt for a finished ride that has already been rated.
  /// Defaults to [onRateDriver] when the caller offers no receipt route.
  final VoidCallback? onViewReceipt;

  /// The rating this passenger already gave, when there is one. A rated trip
  /// offers the receipt instead of asking for a rating again.
  final int? existingRating;

  /// Payment method ids the assigned driver accepts (cash first). Empty until
  /// a driver is assigned, which is also when the passenger may choose.
  final List<String> driverPaymentMethods;

  /// Method the passenger chose, or null while they have not chosen yet.
  final String? selectedPaymentMethod;

  /// Opens the payment method chooser.
  final VoidCallback? onChoosePaymentMethod;

  /// Opens the in-app chat with the driver. Null hides the action.
  final VoidCallback? onMessage;

  /// Whether a driver has been assigned. Call, SMS and Message are meaningless
  /// (and the phone number is unknown) before that.
  final bool hasDriver;

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
    final onCall = widget.onCall;
    final onText = widget.onText;

    // Before the trip starts the passenger can still back out; after it ends
    // they rate the driver. While the trip runs there is no passenger action:
    // starting and completing the ride are the driver's.
    final canCancel =
        status == 'requested' || status == 'accepted' || status == 'driver_arriving';
    final isCompleted = status == 'completed';
    final isInProgress = status == 'in_progress';

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
                      // Flexible so a very large system font shortens the
                      // label instead of overflowing the sheet's header.
                      Flexible(
                        child: Text(
                          _isCollapsed ? 'Show details' : 'Hide details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
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

                    // Call, SMS and in-app message actions. Hidden until a
                    // driver is assigned, since there is nobody to reach yet.
                    if (widget.hasDriver) ...[
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
                            icon: Icons.sms_outlined,
                            color: const Color(0xFF10B981),
                            label: 'Text',
                            size: circleSize,
                            onTap: onText,
                          ),
                          if (widget.onMessage != null) ...[
                            SizedBox(width: isCompact ? 20 : 28),
                            _buildContactCircle(
                              icon: Icons.forum_outlined,
                              color: const Color(0xFF4F46E5),
                              label: 'Message',
                              size: circleSize,
                              onTap: widget.onMessage!,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: gap),
                      Divider(color: Colors.grey.shade200, height: 1),
                      SizedBox(height: gap),
                    ],

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

                    // Payment method: only meaningful once a driver has been
                    // assigned, since the driver decides what they accept.
                    if (widget.driverPaymentMethods.isNotEmpty &&
                        widget.onChoosePaymentMethod != null) ...[
                      SizedBox(height: gap),
                      _buildPaymentRow(textScale),
                    ],
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
              child: _buildPrimaryAction(
                canCancel: canCancel,
                isInProgress: isInProgress,
                isCompleted: isCompleted,
                actionFontSize: actionFontSize,
                isCompact: isCompact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The footer control for the current stage, or nothing when the ride is
  /// entirely in the driver's hands (in progress) or already finished.
  Widget _buildPrimaryAction({
    required bool canCancel,
    required bool isInProgress,
    required bool isCompleted,
    required double actionFontSize,
    required bool isCompact,
  }) {
    if (isInProgress) return _buildDriverOwnedNotice(actionFontSize);
    if (!canCancel && !isCompleted) return const SizedBox.shrink();

    final isRating = isCompleted;
    // Already rated: the receipt shows what was given, so send them there
    // rather than re-opening the rating form.
    final isRatedAlready = isRating && widget.existingRating != null;
    final onPressed = isRating
        ? (isRatedAlready
            ? (widget.onViewReceipt ?? widget.onRateDriver)
            : widget.onRateDriver)
        : widget.onCancelRide;
    return ElevatedButton(
      onPressed: widget.isActioning ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isRating
            ? (isRatedAlready
                ? const Color(0xFF0F172A)
                : const Color(0xFF2563EB))
            : const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 0,
      ),
      child: widget.isActioning
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
                isRating
                    ? (isRatedAlready ? 'View Receipt' : 'Rate Driver')
                    : 'Cancel Ride',
                maxLines: 1,
                style: TextStyle(
                  fontSize: actionFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  /// Replaces the action button once the driver has started the trip: the
  /// passenger has nothing to press, so the footer explains who is in charge.
  Widget _buildDriverOwnedNotice(double actionFontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.electric_rickshaw,
            size: 20,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Trip in progress — your driver completes the ride',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: actionFontSize - 2,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable "how you will pay" row. Cash is shown until the passenger picks
  /// something else, matching what the ride is paid with if they never choose.
  Widget _buildPaymentRow(double textScale) {
    final meta = PaymentMethods.byId(widget.selectedPaymentMethod);
    final hasQr = !meta.isCash;

    return InkWell(
      onTap: widget.onChoosePaymentMethod,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: meta.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: meta.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment method',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    widget.selectedPaymentMethod == null
                        ? '${meta.label} (default)'
                        : meta.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5 * textScale,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            if (hasQr)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.qr_code_2,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ),
            const Text(
              'Change',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
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
          // Constrained to the circle so a large system font shrinks the label
          // instead of widening (and overflowing) the whole row.
          SizedBox(
            width: size,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
