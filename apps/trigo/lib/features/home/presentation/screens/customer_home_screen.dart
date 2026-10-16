import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/utils/geo_bounds.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../notifications/presentation/providers/notification_center.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../widgets/active_ride_card.dart';
import '../widgets/customer_booking_sheet.dart';
import '../widgets/customer_map_view.dart';

enum MapPickingTarget { none, pickup, dropoff }

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _bookingFormKey = GlobalKey<FormState>();
  final _ridesRepository = RidesRepository();
  final _geocodingService = GeocodingService();
  final _mapViewKey = GlobalKey<CustomerMapViewState>();

  int _passengerCount = 1;
  bool _isRequesting = false;
  bool _isResolvingLocation = false;
  List<dynamic> _municipalities = [];
  geo.Position? _currentPosition;
  final _sheetController = DraggableScrollableController();
  LocationSearchResult? _selectedPickupLocation;
  LocationSearchResult? _selectedDropoffLocation;

  /// The ride this passenger already has in flight, or null when idle. While
  /// set, the booking sheet is hidden and a resume card takes its place.
  Map? _activeRide;
  Timer? _activeRideTimer;

  bool get _hasActiveRide => _activeRide != null;

  // In-place map picking state
  MapPickingTarget _pickingTarget = MapPickingTarget.none;
  final _pickerAddressNotifier = ValueNotifier<String>('Locating...');
  final _isPickerGeocodingNotifier = ValueNotifier<bool>(false);
  double? _pickerLat;
  double? _pickerLng;

  /// Rough height of the fully-expanded booking form, used to derive the
  /// sheet's initial fraction so small screens get proportionally smaller
  /// sheets.
  static const double _sheetContentHeight = 340;

  @override
  void initState() {
    super.initState();
    _loadMunicipalities();
    // A ride booked earlier must be visible the moment the passenger lands on
    // Home, even if the tracking screen was left behind or the app restarted.
    _refreshActiveRide();
    _activeRideTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _refreshActiveRide(),
    );
  }

  @override
  void dispose() {
    _activeRideTimer?.cancel();
    _sheetController.dispose();
    _pickerAddressNotifier.dispose();
    _isPickerGeocodingNotifier.dispose();
    super.dispose();
  }

  /// Loads the passenger's in-flight ride, hiding the booking flow while one
  /// exists so a second ride cannot be booked on top of the first.
  Future<void> _refreshActiveRide() async {
    if (!mounted) return;
    try {
      final ride = await _ridesRepository.getActiveRide();
      if (!mounted) return;
      final active = ride is Map ? ride : null;
      if (active?['id'] == _activeRide?['id'] &&
          active?['status'] == _activeRide?['status']) {
        if (active == null) return;
        setState(() => _activeRide = active);
        return;
      }
      setState(() => _activeRide = active);
    } catch (_) {
      // Lookup failures are non-fatal; retried on the next tick
    }
  }

  Future<void> _resumeRide() async {
    final rideId = _activeRide?['id']?.toString();
    if (rideId == null || rideId.isEmpty) return;
    await context.push('/ride/$rideId/tracking');
    // Coming back from the tracking screen, drop the card immediately if the
    // ride has since been cancelled or completed.
    await _refreshActiveRide();
  }

  Future<void> _loadMunicipalities() async {
    try {
      final municipalities = await _ridesRepository.getMunicipalities();
      if (mounted) setState(() => _municipalities = municipalities);
    } catch (_) {
      // Municipality list is optional for the booking flow
    }
    await _refreshCurrentPosition();
  }

  Future<void> _refreshCurrentPosition() async {
    if (_isResolvingLocation) return;
    _isResolvingLocation = true;
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
      if (mounted) setState(() => _currentPosition = pos);
    } catch (_) {
      // Booking falls back to the nearest municipality center without GPS
    } finally {
      _isResolvingLocation = false;
    }
  }

  void _minimizeSheet(double peekSize) {
    if (_sheetController.isAttached && _sheetController.size > peekSize + 0.02) {
      _sheetController.animateTo(
        peekSize,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleSheet(double peekSize, double initialSize) {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    final midpoint = (peekSize + initialSize) / 2;
    final target = current <= midpoint + 0.02 ? initialSize : peekSize;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _startPickingOnMap(MapPickingTarget target) {
    final lat = target == MapPickingTarget.pickup
        ? (_selectedPickupLocation?.latitude ?? _currentPosition?.latitude)
        : (_selectedDropoffLocation?.latitude ?? _currentPosition?.latitude);
    final lng = target == MapPickingTarget.pickup
        ? (_selectedPickupLocation?.longitude ?? _currentPosition?.longitude)
        : (_selectedDropoffLocation?.longitude ?? _currentPosition?.longitude);

    _pickerLat = lat;
    _pickerLng = lng;
    _pickerAddressNotifier.value = 'Locating...';
    _isPickerGeocodingNotifier.value = true;

    setState(() {
      _pickingTarget = target;
    });

    if (lat != null && lng != null) {
      _mapViewKey.currentState?.flyToLocation(lat, lng);
      _resolvePickerAddress(lat, lng);
    }
  }

  Future<void> _resolvePickerAddress(double lat, double lng) async {
    _isPickerGeocodingNotifier.value = true;
    try {
      final address = await _geocodingService.reverseGeocode(lat, lng);
      if (mounted) {
        _pickerAddressNotifier.value = address;
      }
    } catch (_) {
      if (mounted) {
        _pickerAddressNotifier.value =
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
    } finally {
      if (mounted) {
        _isPickerGeocodingNotifier.value = false;
      }
    }
  }

  void _onPickerCameraMoved(double lat, double lng) {
    _pickerLat = lat;
    _pickerLng = lng;
    _resolvePickerAddress(lat, lng);
  }

  MunicipalityMatch? _getCurrentPickupMunicipality() {
    final pLat =
        _selectedPickupLocation?.latitude ?? _currentPosition?.latitude;
    final pLng =
        _selectedPickupLocation?.longitude ?? _currentPosition?.longitude;
    if (pLat != null && pLng != null) {
      return locateMunicipality(pLat, pLng, _municipalities);
    }
    return null;
  }

  /// Bounding box of one service area: its drawn boundary when available,
  /// otherwise its circular fallback radius.
  GeoBounds? _municipalityBounds(MunicipalityMatch match) {
    return boundsFromPolygonRings(getMunicipalityBoundaryRings(match));
  }

  /// Bounding box covering every configured service area. Used to fence pickup
  /// searches so results stay inside the coverage zone — and stay useful even
  /// when there is no GPS fix.
  GeoBounds? _serviceAreaBounds() {
    GeoBounds? bounds;
    for (final municipality in _municipalities) {
      if (municipality is! Map) continue;
      final match = matchFromMunicipalityMap(municipality);
      if (match == null) continue;
      final municipalityBounds = _municipalityBounds(match);
      if (municipalityBounds == null) continue;
      bounds = bounds == null
          ? municipalityBounds
          : bounds.expandToInclude(municipalityBounds);
    }
    return bounds;
  }

  /// Point searches are biased towards: the chosen pickup, else the device
  /// location, else the first configured service area. Never null while a
  /// service area is loaded, so ranking stays distance-aware without GPS.
  double? get _searchBiasLat =>
      _selectedPickupLocation?.latitude ??
      _currentPosition?.latitude ??
      firstMunicipality(_municipalities)?.centerLat;

  double? get _searchBiasLng =>
      _selectedPickupLocation?.longitude ??
      _currentPosition?.longitude ??
      firstMunicipality(_municipalities)?.centerLng;

  /// Tells the user a chosen point sits outside every configured service area,
  /// so it can never be matched with a driver. Called from every place a point
  /// is selected — address search, and the in-place map picker for both the
  /// pickup and the drop-off.
  void _promptNotServiceable() {
    AppSnackBar.error(
      context,
      title: 'Area not serviceable',
      description:
          'Please adjust your location to a point inside a service area.',
    );
  }

  void _confirmPickedLocation() {
    final lat = _pickerLat;
    final lng = _pickerLng;
    if (lat == null || lng == null) return;

    final fullAddr = _pickerAddressNotifier.value;
    final title = fullAddr.split(',').first.trim();
    final subtitle = fullAddr.contains(',')
        ? fullAddr.substring(fullAddr.indexOf(',') + 1).trim()
        : '';

    final result = LocationSearchResult(
      title: title.isNotEmpty ? title : 'Selected Location',
      subtitle: subtitle,
      latitude: lat,
      longitude: lng,
    );

    if (_pickingTarget == MapPickingTarget.pickup) {
      final pickupMatch = locateMunicipality(lat, lng, _municipalities);

      // A pickup outside every service area can never be matched with a driver,
      // so block it here and ask the user to adjust rather than silently
      // accepting an unserviceable booking. Staying in picking mode keeps the
      // pin on screen so they can nudge it into area.
      if (pickupMatch == null) {
        _promptNotServiceable();
        return;
      }

      setState(() {
        _pickupController.text = result.fullAddress;
        _selectedPickupLocation = result;
        _pickingTarget = MapPickingTarget.none;
      });

      // If destination was already selected, verify it remains within this pickup's polygon
      if (_selectedDropoffLocation != null) {
        final isDropoffValid = isPointInsideMunicipality(
          _selectedDropoffLocation!.latitude,
          _selectedDropoffLocation!.longitude,
          pickupMatch,
        );
        if (!isDropoffValid) {
          _dropoffController.clear();
          setState(() => _selectedDropoffLocation = null);
          AppSnackBar.warning(
            context,
            title: 'Destination Cleared',
            description:
                'Previous destination was outside the new service area. Please select a new destination.',
          );
        }
      }
    } else if (_pickingTarget == MapPickingTarget.dropoff) {
      // A drop-off outside every service area is unserviceable no matter where
      // the pickup is, so prompt to adjust before the same-area check below.
      if (locateMunicipality(lat, lng, _municipalities) == null) {
        _promptNotServiceable();
        return; // Block placing destination point
      }

      // Validate that dropoff is inside the boundary of the current pickup's municipality
      final pickupMuni = _getCurrentPickupMunicipality();
      final isDestinationInside =
          pickupMuni == null || isPointInsideMunicipality(lat, lng, pickupMuni);

      if (!isDestinationInside) {
        AppSnackBar.error(
          context,
          title: 'Out of Service Area',
          description:
              'Drop-off must be within the same service area as your pickup.',
        );
        return; // Block placing destination point
      }

      setState(() {
        _dropoffController.text = result.fullAddress;
        _selectedDropoffLocation = result;
        _pickingTarget = MapPickingTarget.none;
      });
    }
  }

  void _cancelPickingOnMap() {
    setState(() => _pickingTarget = MapPickingTarget.none);
  }

  Future<void> _findTrike() async {
    if (_isRequesting) return;
    // Guard rail: the booking sheet is hidden while a ride is in flight, so
    // this must never start a second booking.
    if (_hasActiveRide) return;
    if (!_bookingFormKey.currentState!.validate()) return;
    setState(() => _isRequesting = true);
    try {
      if (_municipalities.isEmpty) {
        await _loadMunicipalities();
      }
      if (_municipalities.isEmpty) {
        throw Exception('No active service areas available');
      }

      final pos = _currentPosition;
      final pickupLat = _selectedPickupLocation?.latitude ?? pos?.latitude;
      final pickupLng = _selectedPickupLocation?.longitude ?? pos?.longitude;

      if (pickupLat == null || pickupLng == null) {
        throw Exception('Please specify a valid pickup location');
      }

      final pickupMatch =
          locateMunicipality(pickupLat, pickupLng, _municipalities);
      if (pickupMatch == null) {
        throw Exception(
            'Area not serviceable. Please adjust your pickup location to a point inside a service area.');
      }

      final dropoffLat = _selectedDropoffLocation?.latitude;
      final dropoffLng = _selectedDropoffLocation?.longitude;

      if (dropoffLat == null || dropoffLng == null) {
        throw Exception('Please select your drop-off destination');
      }

      if (!isPointInsideMunicipality(dropoffLat, dropoffLng, pickupMatch)) {
        throw Exception(
            'Drop-off must be within the same service area as your pickup.');
      }

      final pickup = _pickupController.text.isNotEmpty
          ? _pickupController.text
          : 'Pickup Location';
      final dropoff = _dropoffController.text.isNotEmpty
          ? _dropoffController.text
          : 'Drop-off Destination';

      if (mounted) {
        // Await the flow so the home screen can pick the new ride up as soon
        // as the passenger comes back from choosing a driver / tracking.
        await context.pushNamed('pick-driver', queryParameters: {
          'pickup': pickup,
          'dropoff': dropoff,
          'pickupLat': pickupLat.toString(),
          'pickupLng': pickupLng.toString(),
          'dropoffLat': dropoffLat.toString(),
          'dropoffLng': dropoffLng.toString(),
          'municipalityId': pickupMatch.id,
          'passengers': '$_passengerCount',
        });
        await _refreshActiveRide();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          title: 'Booking Notice',
          description: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isPicking = _pickingTarget != MapPickingTarget.none;

    // Search fencing: pickups anywhere in the coverage zone; drop-offs limited
    // to the pickup's municipality, matching the booking validation below.
    final pickupSearchBounds = _serviceAreaBounds();
    final pickupMunicipality = _getCurrentPickupMunicipality();
    final dropoffSearchBounds = pickupMunicipality != null
        ? _municipalityBounds(pickupMunicipality)
        : pickupSearchBounds;

    final peekSize =
        ((110 + bottomInset) / screenHeight).clamp(0.12, 0.26).toDouble();
    final initialSize =
        ((_sheetContentHeight + bottomInset) / screenHeight)
            .clamp(peekSize + 0.04, 0.75);
    final maxRecenterBottom =
        screenHeight - MediaQuery.of(context).padding.top - 80;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _sheetController,
              builder: (context, _) {
                final extent = _sheetController.isAttached
                    ? _sheetController.size
                    : initialSize;
                final sheetHeight = extent * screenHeight;
                final recenterBottomOffset = _hasActiveRide
                    ? bottomInset + 200
                    : isPicking
                        ? (bottomInset + 180)
                        : math.min(sheetHeight + 12, maxRecenterBottom);

                return CustomerMapView(
                  key: _mapViewKey,
                  municipalities: _municipalities,
                  currentPosition: _currentPosition,
                  bottomOffset: recenterBottomOffset,
                  pickupLocation: _selectedPickupLocation,
                  dropoffLocation: _selectedDropoffLocation,
                  isPickingLocation: isPicking,
                  pickingPinColor: _pickingTarget == MapPickingTarget.pickup
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  pickingPinLabel: _pickingTarget == MapPickingTarget.pickup
                      ? 'Set Pickup Location'
                      : 'Set Drop-off Destination',
                  onCameraCenterChanged: _onPickerCameraMoved,
                );
              },
            ),
          ),

          // Tap anywhere on the visible map above an open sheet to minimize
          if (!isPicking && !_hasActiveRide)
            ListenableBuilder(
              listenable: _sheetController,
              builder: (context, _) {
                final extent = _sheetController.isAttached
                    ? _sheetController.size
                    : initialSize;
                if (extent <= peekSize + 0.04) {
                  return const SizedBox.shrink();
                }
                final sheetHeight = extent * screenHeight;
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: sheetHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _minimizeSheet(peekSize),
                  ),
                );
              },
            ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: NotificationBellButton(
              unreadCount:
                  ref.watch(notificationCenterProvider).unreadCount,
              onTap: () => context.push('/notifications'),
            ),
          ),

          // Regular Draggable Booking Sheet when NOT picking from map and no
          // ride is already in flight.
          if (!isPicking && !_hasActiveRide)
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: initialSize,
              minChildSize: peekSize,
              maxChildSize: 0.90,
              snap: true,
              snapSizes: [peekSize, initialSize],
              builder: (context, scrollController) {
                return CustomerBookingSheet(
                  userName: authState.name,
                  pickupController: _pickupController,
                  dropoffController: _dropoffController,
                  bookingFormKey: _bookingFormKey,
                  passengerCount: _passengerCount,
                  isRequesting: _isRequesting,
                  proximityLat: _searchBiasLat,
                  proximityLng: _searchBiasLng,
                  pickupSearchBounds: pickupSearchBounds,
                  dropoffSearchBounds: dropoffSearchBounds,
                  onPickupSelected: (result) {
                    final match = locateMunicipality(
                        result.latitude, result.longitude, _municipalities);
                    if (match == null) {
                      _pickupController.clear();
                      setState(() => _selectedPickupLocation = null);
                      _promptNotServiceable();
                      return;
                    }
                    setState(() => _selectedPickupLocation = result);
                  },
                  onDropoffSelected: (result) {
                    if (locateMunicipality(
                            result.latitude, result.longitude, _municipalities) ==
                        null) {
                      _dropoffController.clear();
                      setState(() => _selectedDropoffLocation = null);
                      _promptNotServiceable();
                      return;
                    }

                    final pickupMuni = _getCurrentPickupMunicipality();
                    final isInside = pickupMuni == null ||
                        isPointInsideMunicipality(
                            result.latitude, result.longitude, pickupMuni);

                    if (!isInside) {
                      _dropoffController.clear();
                      setState(() => _selectedDropoffLocation = null);
                      AppSnackBar.error(
                        context,
                        title: 'Out of Service Area',
                        description:
                            'Drop-off must be within the same service area as your pickup.',
                      );
                      return;
                    }
                    setState(() => _selectedDropoffLocation = result);
                  },
                  onPickPickupOnMap: () =>
                      _startPickingOnMap(MapPickingTarget.pickup),
                  onPickDropoffOnMap: () =>
                      _startPickingOnMap(MapPickingTarget.dropoff),
                  onIncrementPassenger: () =>
                      setState(() => _passengerCount++),
                  onDecrementPassenger: () => setState(() {
                    if (_passengerCount > 1) {
                      _passengerCount--;
                    }
                  }),
                  onFindTrike: _findTrike,
                  onToggleExpand: () => _toggleSheet(peekSize, initialSize),
                  scrollController: scrollController,
                  bottomInset: bottomInset,
                );
              },
            ),

          // Active ride: the booking sheet is replaced entirely so a passenger
          // mid-ride cannot start a second booking by accident.
          if (_hasActiveRide)
            Positioned(
              left: 14,
              right: 14,
              bottom: bottomInset + 16,
              child: ActiveRideCard(
                ride: _activeRide!,
                isDriver: false,
                onContinue: _resumeRide,
              ),
            ),

          // In-place Map Picking Confirmation Bottom Bar with isolated ValueListenableBuilders
          if (isPicking)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_pickingTarget == MapPickingTarget.pickup
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _pickingTarget == MapPickingTarget.pickup
                                ? Icons.my_location
                                : Icons.location_on,
                            size: 20,
                            color: _pickingTarget == MapPickingTarget.pickup
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickingTarget == MapPickingTarget.pickup
                                    ? 'Select Pickup Location'
                                    : 'Select Drop-off Destination',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              ValueListenableBuilder<bool>(
                                valueListenable: _isPickerGeocodingNotifier,
                                builder: (context, isGeocoding, _) {
                                  if (isGeocoding) {
                                    return const Row(
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Pinpointing address...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return ValueListenableBuilder<String>(
                                    valueListenable: _pickerAddressNotifier,
                                    builder: (context, address, _) {
                                      return Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton(
                            onPressed: _cancelPickingOnMap,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _isPickerGeocodingNotifier,
                            builder: (context, isGeocoding, _) {
                              return ElevatedButton(
                                onPressed: isGeocoding
                                    ? null
                                    : _confirmPickedLocation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _pickingTarget == MapPickingTarget.pickup
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Confirm Location',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
