import 'package:flutter/material.dart';

class IncomingRequestModal extends StatefulWidget {
  final dynamic ride;
  final Future<void> Function() onAccept;

  const IncomingRequestModal({
    super.key,
    required this.ride,
    required this.onAccept,
  });

  /// True while a request sheet is on screen. Guards against stacking: callers
  /// reach [show] both from the 5s poll and from a map-pin tap, and a stacked
  /// duplicate would place an invisible non-dismissible barrier over the
  /// buttons, making them appear unclickable.
  static bool _isShowing = false;

  /// Test-only hook so widget tests can start from a known guard state.
  @visibleForTesting
  static void resetGuardForTesting() => _isShowing = false;

  static Future<void> show(
      BuildContext context, dynamic ride, Future<void> Function() onAccept) {
    if (_isShowing) return Future<void>.value();
    _isShowing = true;

    // Release the guard on every exit path: normal completion, a synchronous
    // failure to present, or the route being torn down by a parent navigator.
    void release() => _isShowing = false;

    try {
      final future = showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            IncomingRequestModal(ride: ride, onAccept: onAccept),
      );
      return future.whenComplete(release);
    } catch (_) {
      release();
      rethrow;
    }
  }

  @override
  State<IncomingRequestModal> createState() => _IncomingRequestModalState();
}

class _IncomingRequestModalState extends State<IncomingRequestModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    try {
      // The caller reports its own failures (a snackbar on Home), so a throw
      // here must still release the button and close the sheet. Anything that
      // keeps this await pending — navigation, for instance — would otherwise
      // leave the driver staring at a spinning ACCEPT RIDE until the trip ends.
      await widget.onAccept();
    } catch (_) {
      // Swallowed on purpose: the sheet is about to close either way.
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride ?? {};
    final passengerName = ride['customerName'] ?? 'Passenger';
    final fare = (ride['fareEstimate'] ?? 0).toDouble().toStringAsFixed(0);
    final distance = (ride['distanceKm'] ?? 0).toDouble().toStringAsFixed(1);
    final pickup = ride['pickupAddress'] ?? 'Pickup';
    final dropoff = ride['dropoffAddress'] ?? 'Drop-off';

    final media = MediaQuery.of(context);
    final bottomPadding = media.padding.bottom;
    final size = media.size;
    // Scale type down rather than overflow when the OS font scale is large.
    final textScale = media.textScaler.scale(1.0).clamp(0.8, 1.3);
    final isCompact = size.height < 640;
    final horizontalInset = size.width < 360 ? 12.0 : 16.0;

    return Container(
      margin: EdgeInsets.fromLTRB(
        horizontalInset,
        horizontalInset,
        horizontalInset,
        bottomPadding > 0 ? bottomPadding + 8 : horizontalInset,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The scroll area gets its own max-height bound so it never
            // demands more room than the viewport can give. Bounding the
            // scroll view directly (rather than using Flexible inside a
            // max-height-constrained Column) avoids passing unbounded
            // constraints into the flex layout pass.
            //
            // The reservation covers the pinned action row (button height,
            // its vertical padding) and is scaled with the text so a large
            // font scale cannot squeeze the row past the viewport edge.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (size.height * 0.92) -
                    ((isCompact ? 108 : 116) * textScale),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isCompact ? 14 : 24,
                  20,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulse Icon. The 1.1 scale needs ~88px of layout height, so
                    // the slot is sized to match instead of clipping at 80.
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: Center(
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF), // blue-50
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFBFDBFE), // blue-200
                                width: 8,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_run,
                                color: Color(0xFF2563EB), // blue-600
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),

                    Text(
                      'New Ride Request!',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24 * textScale,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person,
                              size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              passengerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 16 : 24),

                    // Route Details
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _RouteRow(
                            icon: Icons.my_location,
                            iconColor: const Color(0xFF059669),
                            iconBackground: const Color(0xFFD1FAE5),
                            label: 'Pickup',
                            value: pickup,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 15.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 20,
                                width: 2,
                                color: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          _RouteRow(
                            icon: Icons.location_on,
                            iconColor: const Color(0xFFDC2626),
                            iconBackground: const Color(0xFFFEE2E2),
                            label: 'Drop-off',
                            value: dropoff,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fare & Distance Highlights.
                    // IntrinsicHeight lets both tiles share the taller tile's
                    // height without stretching them against unbounded
                    // constraints, which a scrollable parent cannot provide.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _HighlightTile(
                              label: 'Est. Fare',
                              value: '\u20B1$fare',
                              valueColor: const Color(0xFF2563EB),
                              background: const Color(0xFFEFF6FF),
                              textScale: textScale,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HighlightTile(
                              label: 'Distance',
                              value: '$distance km',
                              valueColor: const Color(0xFF0F172A),
                              background: Colors.grey.shade50,
                              textScale: textScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Action buttons stay pinned below the scroll area so they are
            // always visible and tappable regardless of content height.
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, isCompact ? 14 : 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isAccepting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16 * textScale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isAccepting ? null : _accept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981), // emerald-500
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isAccepting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'ACCEPT RIDE',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 16 * textScale,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single pickup/drop-off line inside the route card. The address is capped
/// at two lines so a long value cannot force the sheet past the viewport.
class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fare/distance tile sized to its content so both tiles in the row match.
class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.background,
    required this.textScale,
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color background;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 24 * textScale,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
