import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ride_booking/data/rides_repository.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/utils/municipality_locator.dart';
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
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _pickerAddressNotifier.dispose();
    _isPickerGeocodingNotifier.dispose();
    super.dispose();
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

      setState(() {
        _pickupController.text = result.fullAddress;
        _selectedPickupLocation = result;
        _pickingTarget = MapPickingTarget.none;
      });

      // If destination was already selected, verify it remains within this pickup's polygon
      if (_selectedDropoffLocation != null && pickupMatch != null) {
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
      // Validate that dropoff is inside the polygon boundary of the current pickup location
      final pickupMuni = _getCurrentPickupMunicipality();
      bool isDestinationInside = false;

      if (pickupMuni != null) {
        isDestinationInside =
            isPointInsideMunicipality(lat, lng, pickupMuni);
      } else {
        isDestinationInside =
            locateMunicipality(lat, lng, _municipalities) != null;
      }

      if (!isDestinationInside) {
        AppSnackBar.error(
          context,
          title: 'Out of Service Area',
          description: 'Drop-off destination is outside the serviceable area..',
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
            'Pickup location is outside our service area. Please select a point within the covered zone.');
      }

      final dropoffLat = _selectedDropoffLocation?.latitude;
      final dropoffLng = _selectedDropoffLocation?.longitude;

      if (dropoffLat == null || dropoffLng == null) {
        throw Exception('Please select your drop-off destination');
      }

      if (!isPointInsideMunicipality(dropoffLat, dropoffLng, pickupMatch)) {
        throw Exception(
            'Drop-off destination is outside the serviceable area..');
      }

      final pickup = _pickupController.text.isNotEmpty
          ? _pickupController.text
          : 'Pickup Location';
      final dropoff = _dropoffController.text.isNotEmpty
          ? _dropoffController.text
          : 'Drop-off Destination';

      if (mounted) {
        context.pushNamed('pick-driver', queryParameters: {
          'pickup': pickup,
          'dropoff': dropoff,
          'pickupLat': pickupLat.toString(),
          'pickupLng': pickupLng.toString(),
          'dropoffLat': dropoffLat.toString(),
          'dropoffLng': dropoffLng.toString(),
          'municipalityId': pickupMatch.id,
          'passengers': '$_passengerCount',
        });
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
                final recenterBottomOffset = isPicking
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
          if (!isPicking)
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
            child: GestureDetector(
              onTap: () => context.push('/notifications'),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_none,
                    color: Colors.white, size: 28),
              ),
            ),
          ),

          // Regular Draggable Booking Sheet when NOT picking from map
          if (!isPicking)
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
                  proximityLat: _currentPosition?.latitude,
                  proximityLng: _currentPosition?.longitude,
                  onPickupSelected: (result) {
                    final match = locateMunicipality(
                        result.latitude, result.longitude, _municipalities);
                    if (match == null) {
                      _pickupController.clear();
                      setState(() => _selectedPickupLocation = null);
                      AppSnackBar.error(
                        context,
                        title: 'Out of Service Area',
                        description:
                            'Pickup location is outside our service area. Please select a point within the covered zone.',
                      );
                      return;
                    }
                    setState(() => _selectedPickupLocation = result);
                  },
                  onDropoffSelected: (result) {
                    final pickupMuni = _getCurrentPickupMunicipality();
                    bool isInside = false;
                    if (pickupMuni != null) {
                      isInside = isPointInsideMunicipality(
                          result.latitude, result.longitude, pickupMuni);
                    } else {
                      isInside = locateMunicipality(result.latitude,
                              result.longitude, _municipalities) !=
                          null;
                    }

                    if (!isInside) {
                      _dropoffController.clear();
                      setState(() => _selectedDropoffLocation = null);
                      AppSnackBar.error(
                        context,
                        title: 'Out of Service Area',
                        description:
                            'Drop-off destination is outside the serviceable area..',
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
