import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messaging/presentation/widgets/ride_chat_sheet.dart';
import '../../../notifications/presentation/providers/notification_center.dart';
import '../../../payments/data/payment_methods_repository.dart';
import '../../../payments/presentation/widgets/passenger_payment_method_sheet.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../core/constants/payment_methods.dart';
import '../../../../shared/utils/phone_actions.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../widgets/ride_tracking_map_view.dart';
import '../widgets/passenger_ride_tracking_sheet.dart';
import '../widgets/driver_ride_tracking_sheet.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String? rideId;

  /// Set when the screen was opened from a message notification, so the thread
  /// opens by itself once the ride is known and a driver is assigned.
  final bool openChatOnLoad;

  const RideTrackingScreen({
    super.key,
    this.rideId,
    this.openChatOnLoad = false,
  });

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  final _repository = RidesRepository();
  final _driversRepository = DriversRepository();
  final _paymentMethodsRepository = PaymentMethodsRepository();
  dynamic _ride;
  bool _isLoading = true;
  bool _isActioning = false;
  Timer? _pollTimer;
  Timer? _locationTimer;

  /// Distance-filtered position updates for the driver.
  StreamSubscription<geo.Position>? _positionSubscription;

  /// The driver's own live GPS fix, used as the map's start point for the
  /// "heading to passenger" leg.
  geo.Position? _ownPosition;

  /// Measured height of the bottom sheet, so the map's floating controls can
  /// sit just above it instead of behind it.
  double _sheetHeight = 0;

  /// Whether the passenger has already been asked how they will pay for this
  /// trip; asked once, when the driver starts the ride.
  bool _hasPromptedPaymentMethod = false;

  /// Guards the one-shot chat open used when arriving from a message alert.
  bool _hasOpenedChatOnLoad = false;

  String? get _effectiveRideId =>
      (widget.rideId == null || widget.rideId!.isEmpty) ? null : widget.rideId;

  @override
  void initState() {
    super.initState();
    if (_effectiveRideId != null) {
      _loadRide();
      // Poll while the ride progresses so driver assignment, live coordinates,
      // and status transitions update in real time
      _pollTimer =
          Timer.periodic(const Duration(seconds: 4), (_) => _loadRide());
      _startOwnLocationUpdates();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// How far the driver must move before a new position is broadcast.
  ///
  /// Kept in step with the map's polyline re-route threshold
  /// (`routeRefreshDistanceKm`) so the drawn line and the uploaded position
  /// advance together; a mismatch would leave one visibly behind the other.
  static const int _broadcastDistanceFilterMeters = 50;

  /// Slow safety net so a parked driver's position does not go stale, since a
  /// pure distance filter emits nothing while they are stationary.
  static const Duration _stationaryHeartbeat = Duration(seconds: 30);

  /// Publishes this device's position for the driver so the map can draw the
  /// driver-to-passenger leg, and so the passenger's poll of the ride payload
  /// sees a fresh driver location. Harmless for passengers.
  void _startOwnLocationUpdates() {
    _refreshOwnPosition();

    // Movement-driven updates: the platform only emits once the driver has
    // actually travelled the filter distance, so a moving vehicle updates
    // promptly instead of waiting for the next timer tick.
    _positionSubscription?.cancel();
    _positionSubscription = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: _broadcastDistanceFilterMeters,
      ),
    ).listen(
      _handlePosition,
      onError: (_) {
        // Stream errors are non-fatal; the heartbeat keeps things ticking.
      },
    );

    _locationTimer =
        Timer.periodic(_stationaryHeartbeat, (_) => _refreshOwnPosition());
  }

  void _handlePosition(geo.Position pos) {
    if (!mounted) return;
    setState(() => _ownPosition = pos);
    _broadcastPosition(pos);
  }

  Future<void> _refreshOwnPosition() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever ||
          !await geo.Geolocator.isLocationServiceEnabled()) {
        return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() => _ownPosition = pos);

      // Broadcast so the passenger's 4s poll of the ride payload receives an
      // up-to-date driver position. The driver Home screen only broadcasts
      // while the driver sits on Home, so without this the passenger's driver
      // marker goes stale for the whole trip.
      await _broadcastPosition(pos);
    } catch (_) {
      // A missing fix is non-fatal: the map falls back to ride coordinates.
    }
  }

  /// Sends the current fix to the tracking endpoint, tagged with the ride so
  /// the backend can also record the trip's path.
  Future<void> _broadcastPosition(geo.Position pos) async {
    final authState = ref.read(authProvider);
    if (authState.activeMode != AppUserMode.driver) return;
    final rideId = _effectiveRideId;
    if (rideId == null) return;
    try {
      await _driversRepository.broadcastLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        rideId: rideId,
      );
    } catch (_) {
      // Broadcast failures are non-fatal; retried on the next tick.
    }
  }

  Future<void> _loadRide() async {
    try {
      final ride = await _repository.getRideById(_effectiveRideId!);
      if (mounted && ride != null) {
        setState(() {
          _ride = ride;
          _isLoading = false;
        });

        // Ask for a rating when the trip completes — but only if it has not
        // been rated already, so a rated trip never prompts twice.
        if (ride['status'] == 'completed') {
          final authState = ref.read(authProvider);
          final isDriver = authState.activeMode == AppUserMode.driver;
          if (!isDriver && RidesRepository.ratingOf(ride) == null) {
            _pollTimer?.cancel();
            context.push('/ride/${widget.rideId}/rating');
          }
        } else if (ride['status'] == 'in_progress') {
          // The passenger has no complete-ride action any more, so ask how
          // they will pay as soon as the trip starts — before the driver can
          // end it.
          _schedulePaymentPrompt();
        }
        _maybeOpenChatOnLoad();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opens the chat once when the screen was reached from a message
  /// notification, as soon as a driver exists to talk to.
  void _maybeOpenChatOnLoad() {
    if (!widget.openChatOnLoad || _hasOpenedChatOnLoad) return;
    if (!_hasAssignedDriver) return;

    _hasOpenedChatOnLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openChat();
    });
  }

  /// Fare text for the payment chooser, matching the sheet's value.
  String get _fareText {
    final fareEstimate = (_ride?['fareEstimate'] as num?)?.toDouble() ?? 45.0;
    return '\u20B1${fareEstimate.toStringAsFixed(0)}';
  }

  /// Asks the passenger for a payment method once the ride has started, unless
  /// they already chose one (or already dismissed this prompt).
  void _schedulePaymentPrompt() {
    if (_hasPromptedPaymentMethod) return;
    final authState = ref.read(authProvider);
    if (authState.activeMode == AppUserMode.driver) return;
    if (_ride?['paymentMethod'] != null) return;

    _hasPromptedPaymentMethod = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _ride?['paymentMethod'] != null) return;
      await _choosePaymentMethod(_fareText);
    });
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel this ride?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Are you sure you want to cancel your ride request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Ride'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cancel Ride'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActioning = true);
    try {
      await _repository.cancelRide(_effectiveRideId!,
          reason: 'Cancelled by customer');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride cancelled')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _handleDriverStepAction() async {
    final currentStatus = _ride?['status'] as String? ?? 'accepted';
    setState(() => _isActioning = true);

    try {
      if (currentStatus == 'accepted') {
        final updated = await _repository.arrive(_effectiveRideId!);
        if (mounted) setState(() => _ride = updated);
      } else if (currentStatus == 'driver_arriving') {
        final updated = await _repository.startRide(_effectiveRideId!);
        if (mounted) setState(() => _ride = updated);
      } else if (currentStatus == 'in_progress') {
        final updated = await _repository.completeRide(_effectiveRideId!);
        if (mounted) {
          setState(() => _ride = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride completed successfully!')),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  /// Whether a driver is committed to this ride. Payment methods only mean
  /// something once someone is actually driving.
  bool get _hasAssignedDriver => _ride?['driverId'] != null;

  /// The passenger may choose how to pay once a driver has accepted and before
  /// the trip finishes.
  bool get _canChoosePaymentMethod {
    if (!_hasAssignedDriver) return false;
    final status = _ride?['status'] as String?;
    return status == 'accepted' ||
        status == 'driver_arriving' ||
        status == 'in_progress';
  }

  /// Payment methods the assigned driver accepts, cash first.
  List<String> get _driverPaymentMethodIds => EnabledPaymentMethod.listFrom(
        _ride?['driverPaymentMethods'],
      ).map((method) => method.method).toList();

  /// Opens the chooser and stores the passenger's choice.
  ///
  /// Returns true once a method is on the ride (either just chosen or already
  /// chosen earlier), false when the passenger backs out without one.
  Future<bool> _choosePaymentMethod(String fareText) async {
    final rideId = _effectiveRideId;
    if (rideId == null) return false;

    final chosen = await showPassengerPaymentMethodSheet(
      context,
      methods: EnabledPaymentMethod.listFrom(_ride?['driverPaymentMethods']),
      selectedMethod: _ride?['paymentMethod'] as String?,
      fareText: fareText,
      driverName: (_ride?['driverName'] as String?) ?? 'your driver',
    );
    if (chosen == null || !mounted) {
      return _ride?['paymentMethod'] != null;
    }

    try {
      final updated =
          await _paymentMethodsRepository.setRidePaymentMethod(rideId, chosen);
      if (mounted && updated != null) {
        setState(() => _ride = updated);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      return _ride?['paymentMethod'] != null;
    }
  }

  /// Opens the in-app thread with the other party of this ride.
  Future<void> _openChat() async {
    final rideId = _effectiveRideId;
    final ride = _ride;
    if (rideId == null || ride is! Map) return;

    final isDriver = ref.read(authProvider).activeMode == AppUserMode.driver;
    final otherPartyName = (isDriver ? ride['customerName'] : ride['driverName'])
            ?.toString() ??
        (isDriver ? 'Passenger' : 'Driver');
    final otherPartyPhone =
        (isDriver ? ride['customerPhone'] : ride['driverPhone'])?.toString();

    await showRideChatSheet(
      context,
      rideId: rideId,
      otherPartyName: otherPartyName,
      currentUserId: ref.read(authProvider).userId,
      otherPartyPhone: otherPartyPhone,
      plateNumber:
          isDriver ? null : ride['tricyclePlateNumber']?.toString(),
      // Opening the thread clears its unread alerts from the bell.
      onThreadRead: () => ref
          .read(notificationCenterProvider.notifier)
          .markRideMessagesRead(rideId),
    );
  }

  /// Hands off to the dialer or the SMS app, falling back to showing the
  /// number when neither can be opened.
  Future<void> _contact({
    required bool isCall,
    required String name,
    required String phone,
  }) async {
    if (phone.trim().isEmpty) {
      _showContactModal(name: name, phone: phone, isCall: isCall);
      return;
    }

    final launched =
        isCall ? await PhoneActions.placeCall(phone) : await PhoneActions.sendSms(phone);
    if (launched || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCall
              ? 'Could not open the phone app on this device'
              : 'Could not open the messaging app on this device',
        ),
      ),
    );
    _showContactModal(name: name, phone: phone, isCall: isCall);
  }

  void _showContactModal({
    required String name,
    required String phone,
    required bool isCall,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(modalContext).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Icon(
                isCall ? Icons.phone_forwarded : Icons.message,
                color:
                    isCall ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                isCall ? 'Call $name' : 'Message $name',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                phone.isNotEmpty ? phone : 'Phone number not available',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              // The in-app thread is always available, even when the phone
              // handoff is not.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(modalContext);
                    _openChat();
                  },
                  icon: const Icon(Icons.forum_outlined, size: 18),
                  label: Text('Message $name in the app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number copied!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Number'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Dismiss'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDriver = authState.activeMode == AppUserMode.driver;

    final rideStatus = (_ride?['status'] as String?) ?? 'requested';
    final pLat = (_ride?['pickupLat'] as num?)?.toDouble();
    final pLng = (_ride?['pickupLng'] as num?)?.toDouble();
    final dLat = (_ride?['dropoffLat'] as num?)?.toDouble();
    final dLng = (_ride?['dropoffLng'] as num?)?.toDouble();
    final drvLat = (_ride?['driverLat'] as num?)?.toDouble();
    final drvLng = (_ride?['driverLng'] as num?)?.toDouble();
    final distanceKm = (_ride?['distanceKm'] as num?)?.toDouble() ?? 1.2;

    final fareText = _fareText;

    final passengerName =
        _ride?['customerName'] ?? _ride?['userName'] ?? 'Passenger';
    final passengerPhone = _ride?['customerPhone'] ?? _ride?['userPhone'] ?? '';
    final driverName = _ride?['driverName'] ?? 'Waiting for driver...';
    final driverPhone = _ride?['driverPhone'] ?? '';
    final plate = _ride?['tricyclePlateNumber'] ?? 'ABC-1234';
    final pickupAddress = _ride?['pickupAddress'] ?? 'Pickup Location';
    final dropoffAddress = _ride?['dropoffAddress'] ?? 'Drop-off Destination';

    String statusHeadline;
    if (rideStatus == 'requested') {
      statusHeadline = 'Finding your nearby driver...';
    } else if (rideStatus == 'accepted') {
      statusHeadline = 'Your driver is on the way';
    } else if (rideStatus == 'driver_arriving') {
      statusHeadline = 'Your driver has arrived!';
    } else if (rideStatus == 'in_progress') {
      statusHeadline = 'Enjoy your ride!';
    } else if (rideStatus == 'completed') {
      statusHeadline = 'Ride completed';
    } else {
      statusHeadline = 'Ride in progress';
    }

    final etaMinutes = (distanceKm * 2.5).clamp(2, 20).round();
    final etaText = '$etaMinutes min';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Full-screen Mapbox Map Viewer
          Positioned.fill(
            child: RideTrackingMapView(
              isDriver: isDriver,
              pickupLat: pLat,
              pickupLng: pLng,
              dropoffLat: dLat,
              dropoffLng: dLng,
              // Prefer the live GPS fix for the driver's own device so their
              // pin and the "to pickup" leg stay accurate even before the
              // backend has a broadcast position. The passenger falls back to
              // the driver coordinates carried on the ride payload.
              driverLat: isDriver ? (_ownPosition?.latitude ?? drvLat) : drvLat,
              driverLng:
                  isDriver ? (_ownPosition?.longitude ?? drvLng) : drvLng,
              distanceKm: distanceKm,
              bottomOffset: _sheetHeight,
              rideStatus: rideStatus,
              // The viewer's own position, so the map opens centred on "where
              // I am" rather than on the midpoint of every tracked point.
              ownLat: _ownPosition?.latitude,
              ownLng: _ownPosition?.longitude,
            ),
          ),

          // 2. Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: const AppBackButton(
              iconColor: Colors.black,
              backgroundColor: Colors.white,
              fallbackLocation: '/home',
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),

          // 3. Active Ride Bottom Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MeasureSize(
              // Report the sheet's real height so the map controls can float
              // above it rather than being hidden underneath.
              onChange: (size) {
                if (!mounted) return;
                if ((size.height - _sheetHeight).abs() < 1) return;
                setState(() => _sheetHeight = size.height);
              },
              child: _isLoading
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : isDriver
                      ? DriverRideTrackingSheet(
                          passengerName: passengerName,
                          passengerCount:
                              (_ride?['passengers'] as num?)?.toInt() ?? 1,
                          pickupAddress: pickupAddress,
                          dropoffAddress: dropoffAddress,
                          fare: fareText,
                          status: rideStatus,
                          isActioning: _isActioning,
                          // Shown only once the passenger has actually
                          // confirmed how they will pay; the 4s ride poll
                          // makes it appear on the driver's sheet by itself.
                          paymentLabel: _ride?['paymentMethod'] == null
                              ? null
                              : PaymentMethods.labelFor(
                                  _ride?['paymentMethod'] as String?),
                          onCall: () => _contact(
                            isCall: true,
                            name: passengerName,
                            phone: passengerPhone,
                          ),
                          onText: () => _contact(
                            isCall: false,
                            name: passengerName,
                            phone: passengerPhone,
                          ),
                          onMessage: _hasAssignedDriver ? _openChat : null,
                          onStepAction: _handleDriverStepAction,
                        )
                      : PassengerRideTrackingSheet(
                          statusText: statusHeadline,
                          driverName: driverName,
                          plateNumber: plate,
                          fare: fareText,
                          eta: etaText,
                          status: rideStatus,
                          isActioning: _isActioning,
                          hasDriver: _hasAssignedDriver,
                          driverPaymentMethods: _canChoosePaymentMethod
                              ? _driverPaymentMethodIds
                              : const [],
                          selectedPaymentMethod:
                              _ride?['paymentMethod'] as String?,
                          onChoosePaymentMethod: _canChoosePaymentMethod
                              ? () => _choosePaymentMethod(fareText)
                              : null,
                          onCall: () => _contact(
                            isCall: true,
                            name: driverName,
                            phone: driverPhone,
                          ),
                          onText: () => _contact(
                            isCall: false,
                            name: driverName,
                            phone: driverPhone,
                          ),
                          onMessage: _hasAssignedDriver ? _openChat : null,
                          // Before the trip: the passenger may back out.
                          onCancelRide: _cancelRide,
                          // After the trip: rating is the passenger's only
                          // remaining action — completing the ride is the
                          // driver's. A trip that is already rated shows the
                          // receipt instead of asking again.
                          existingRating: _ride == null
                              ? null
                              : RidesRepository.ratingOf(_ride as Map),
                          onRateDriver: () =>
                              context.push('/ride/${widget.rideId}/rating'),
                          onViewReceipt: () => context
                              .push('/ride/${widget.rideId}/details'),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reports its child's size after layout, so a sibling (the map's floating
/// controls) can be offset by the real measured height instead of a guess.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final void Function(Size size) onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  void Function(Size size) onChange;

  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_lastSize == newSize) return;
    _lastSize = newSize;
    // Report after the frame so the listener can safely call setState.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
