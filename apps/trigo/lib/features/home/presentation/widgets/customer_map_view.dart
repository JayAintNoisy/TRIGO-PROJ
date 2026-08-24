import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../shared/services/directions_service.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../../shared/widgets/map_recenter_button.dart';

/// Full-screen map for the customer home screen: the customer's position,
/// selected pickup/dropoff locations, route polyline directions,
/// interactive in-place map location picker, and municipality boundary.
class CustomerMapView extends StatefulWidget {
  const CustomerMapView({
    super.key,
    required this.municipalities,
    this.currentPosition,
    this.bottomOffset,
    this.pickupLocation,
    this.dropoffLocation,
    this.isPickingLocation = false,
    this.pickingPinColor = const Color(0xFF2563EB),
    this.pickingPinLabel = 'Set location here',
    this.onCameraCenterChanged,
  });

  final List<dynamic> municipalities;

  /// Latest GPS fix from the owning screen.
  final geo.Position? currentPosition;

  /// Bottom offset for positioning the floating recenter button above bottom sheets.
  final double? bottomOffset;

  /// Selected pickup location from search or map picker.
  final LocationSearchResult? pickupLocation;

  /// Selected drop-off destination from search or map picker.
  final LocationSearchResult? dropoffLocation;

  /// Whether the map is currently in location picking mode with a center pin.
  final bool isPickingLocation;

  /// Pin color when in location picking mode.
  final Color pickingPinColor;

  /// Pin label banner text when in location picking mode.
  final String pickingPinLabel;

  /// Callback when camera center changes in location picking mode.
  final void Function(double lat, double lng)? onCameraCenterChanged;

  @override
  State<CustomerMapView> createState() => CustomerMapViewState();
}

class CustomerMapViewState extends State<CustomerMapView> {
  // Bukidnon centroid used when GPS and municipality data are unavailable
  static const _fallbackLat = 8.1575;
  static const _fallbackLng = 125.1278;

  MapboxMap? _controller;
  CircleAnnotationManager? _positionManager;
  CircleAnnotationManager? _routePointsManager;
  PolylineAnnotationManager? _polylineManager;

  final _directionsService = DirectionsService();
  Timer? _cameraDebounceTimer;

  late final double _startLat;
  late final double _startLng;
  late final Widget _mapWidget;

  double _lastReportedLat = 0;
  double _lastReportedLng = 0;
  bool _isRecentering = false;

  @override
  void initState() {
    super.initState();
    final pos = widget.currentPosition;
    if (pos != null) {
      _startLat = pos.latitude;
      _startLng = pos.longitude;
    } else {
      final nearest = _nearestOrFirst();
      if (nearest != null) {
        _startLat = nearest.centerLat;
        _startLng = nearest.centerLng;
      } else {
        _startLat = _fallbackLat;
        _startLng = _fallbackLng;
      }
    }
    _lastReportedLat = _startLat;
    _lastReportedLng = _startLng;

    // Cache MapWidget once so parent rebuilds NEVER reset camera
    _mapWidget = MapWidget(
      key: const ValueKey('customer_home_map_instance'),
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(_startLng, _startLat),
        ),
        zoom: 14,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      onCameraChangeListener: _onCameraChanged,
    );
  }

  @override
  void dispose() {
    _cameraDebounceTimer?.cancel();
    super.dispose();
  }

  MunicipalityMatch? _nearestOrFirst() {
    if (widget.municipalities.isEmpty) return null;
    final pos = widget.currentPosition;
    if (pos != null) {
      final match = locateMunicipality(
          pos.latitude, pos.longitude, widget.municipalities);
      if (match != null) return match;
    }
    return firstMunicipality(widget.municipalities);
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));

    _positionManager =
        await controller.annotations.createCircleAnnotationManager();
    _routePointsManager =
        await controller.annotations.createCircleAnnotationManager();
    _polylineManager =
        await controller.annotations.createPolylineAnnotationManager();

    await _drawUserPosition();
    await _drawRouteAndMarkers();

    // Recenter map once loaded
    final pos = widget.currentPosition;
    if (pos != null) {
      await controller.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 600),
      );
    }

    if (widget.isPickingLocation) {
      _reportCurrentCenter();
    }
  }

  void _onCameraChanged(CameraChangedEventData event) {
    if (!widget.isPickingLocation) return;
    _cameraDebounceTimer?.cancel();
    _cameraDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _reportCurrentCenter();
    });
  }

  Future<void> _reportCurrentCenter() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    try {
      final state = await controller.getCameraState();
      final center = state.center;
      final lat = center.coordinates.lat.toDouble();
      final lng = center.coordinates.lng.toDouble();

      // Only notify if position moved more than ~5 meters
      if ((lat - _lastReportedLat).abs() > 0.00005 ||
          (lng - _lastReportedLng).abs() > 0.00005) {
        _lastReportedLat = lat;
        _lastReportedLng = lng;
        widget.onCameraCenterChanged?.call(lat, lng);
      }
    } catch (_) {}
  }

  /// Programmatically moves camera to coordinates
  Future<void> flyToLocation(double lat, double lng, {double zoom = 15.5}) async {
    final controller = _controller;
    if (controller != null) {
      _lastReportedLat = lat;
      _lastReportedLng = lng;
      await controller.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: zoom,
        ),
        MapAnimationOptions(duration: 700),
      );
      if (widget.isPickingLocation) {
        widget.onCameraCenterChanged?.call(lat, lng);
      }
    }
  }

  Future<void> _recenterOnGps() async {
    if (_isRecentering) return;
    setState(() => _isRecentering = true);
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
      final controller = _controller;
      if (controller != null) {
        _lastReportedLat = pos.latitude;
        _lastReportedLng = pos.longitude;
        await controller.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 15.5,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
      if (widget.isPickingLocation) {
        widget.onCameraCenterChanged?.call(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    if (mounted) setState(() => _isRecentering = false);
  }

  @override
  void didUpdateWidget(CustomerMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.municipalities != widget.municipalities) {
      _drawUserPosition();
      if (oldWidget.currentPosition == null &&
          widget.currentPosition != null &&
          !widget.isPickingLocation) {
        _recenterOnGps();
      }
    }
    if (oldWidget.pickupLocation != widget.pickupLocation ||
        oldWidget.dropoffLocation != widget.dropoffLocation ||
        oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.isPickingLocation != widget.isPickingLocation) {
      _drawRouteAndMarkers();
    }
    if (!oldWidget.isPickingLocation && widget.isPickingLocation) {
      _reportCurrentCenter();
    }
  }

  Future<void> _drawUserPosition() async {
    final manager = _positionManager;
    if (manager == null) return;
    await manager.deleteAll();

    final pos = widget.currentPosition;
    if (pos == null) return;

    final point = Point(coordinates: Position(pos.longitude, pos.latitude));

    // Outer pulse ring
    await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 16.0,
      circleColor: const Color(0xFF2563EB).withValues(alpha: 0.2).toARGB32(),
      circleStrokeWidth: 0,
    ));

    // Core dot
    await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 8.0,
      circleColor: const Color(0xFF2563EB).toARGB32(),
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeOpacity: 1.0,
    ));
  }

  Future<void> _drawRouteAndMarkers() async {
    final polyManager = _polylineManager;
    final pointManager = _routePointsManager;
    if (polyManager == null || pointManager == null) return;

    await polyManager.deleteAll();
    await pointManager.deleteAll();

    // Hide destination/route markers during live map picking
    if (widget.isPickingLocation) return;

    final pickup = widget.pickupLocation;
    final dropoff = widget.dropoffLocation;

    final pickupLat = pickup?.latitude ?? widget.currentPosition?.latitude;
    final pickupLng = pickup?.longitude ?? widget.currentPosition?.longitude;
    final dropoffLat = dropoff?.latitude;
    final dropoffLng = dropoff?.longitude;

    // Draw Pickup Marker (Green)
    if (pickupLat != null &&
        pickupLng != null &&
        (pickup != null || dropoff != null)) {
      final pPoint = Point(coordinates: Position(pickupLng, pickupLat));
      // Outer ring
      await pointManager.create(CircleAnnotationOptions(
        geometry: pPoint,
        circleRadius: 13.0,
        circleColor: const Color(0xFF10B981).withValues(alpha: 0.25).toARGB32(),
        circleStrokeWidth: 0,
      ));
      // Core dot
      await pointManager.create(CircleAnnotationOptions(
        geometry: pPoint,
        circleRadius: 7.0,
        circleColor: const Color(0xFF10B981).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }

    // Draw Dropoff Marker (Red)
    if (dropoffLat != null && dropoffLng != null) {
      final dPoint = Point(coordinates: Position(dropoffLng, dropoffLat));
      // Outer ring
      await pointManager.create(CircleAnnotationOptions(
        geometry: dPoint,
        circleRadius: 13.0,
        circleColor: const Color(0xFFEF4444).withValues(alpha: 0.25).toARGB32(),
        circleStrokeWidth: 0,
      ));
      // Core dot
      await pointManager.create(CircleAnnotationOptions(
        geometry: dPoint,
        circleRadius: 7.0,
        circleColor: const Color(0xFFEF4444).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }

    // Draw Route Polyline & Fit Camera when both points exist
    if (pickupLat != null &&
        pickupLng != null &&
        dropoffLat != null &&
        dropoffLng != null) {
      final route = await _directionsService.getRoute(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );

      if (route != null && route.coordinates.length >= 2) {
        // Casing / glow line
        await polyManager.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: route.coordinates),
          lineColor: const Color(0xFF1E40AF).withValues(alpha: 0.35).toARGB32(),
          lineWidth: 7.5,
          lineJoin: LineJoin.ROUND,
        ));

        // Vibrant main route line
        await polyManager.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: route.coordinates),
          lineColor: const Color(0xFF2563EB).toARGB32(),
          lineWidth: 4.5,
          lineJoin: LineJoin.ROUND,
        ));
      }

      _frameRouteBounds(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
    }
  }

  void _frameRouteBounds({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    final controller = _controller;
    if (controller == null) return;

    final centerLat = (pickupLat + dropoffLat) / 2;
    final centerLng = (pickupLng + dropoffLng) / 2;
    final distKm = haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);

    double zoom;
    if (distKm < 0.8) {
      zoom = 15.5;
    } else if (distKm < 2.0) {
      zoom = 14.5;
    } else if (distKm < 5.0) {
      zoom = 13.5;
    } else if (distKm < 10.0) {
      zoom = 12.5;
    } else if (distKm < 20.0) {
      zoom = 11.5;
    } else {
      zoom = 10.5;
    }

    controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 900),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: _mapWidget,
        ),

        // Centered pin marker for in-place location picking
        if (widget.isPickingLocation)
          Center(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.pickingPinLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.location_on,
                      color: widget.pickingPinColor,
                      size: 44,
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          right: 16,
          bottom: widget.bottomOffset ??
              (MediaQuery.of(context).padding.bottom + 360),
          child: MapRecenterButton(
            onPressed: _recenterOnGps,
            isLoading: _isRecentering,
            color: widget.isPickingLocation
                ? widget.pickingPinColor
                : const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }
}
