import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../shared/services/directions_service.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../../shared/widgets/map_recenter_button.dart';

/// Full-screen Mapbox map for ride tracking with live driver position,
/// pickup/dropoff pins, route directions polyline, and distance badge.
class RideTrackingMapView extends StatefulWidget {
  const RideTrackingMapView({
    super.key,
    required this.isDriver,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.driverLat,
    this.driverLng,
    this.distanceKm,
    this.bottomOffset,
  });

  final bool isDriver;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? driverLat;
  final double? driverLng;
  final double? distanceKm;
  final double? bottomOffset;

  @override
  State<RideTrackingMapView> createState() => _RideTrackingMapViewState();
}

class _RideTrackingMapViewState extends State<RideTrackingMapView> {
  static const _fallbackLat = 8.1575;
  static const _fallbackLng = 125.1278;

  MapboxMap? _controller;
  CircleAnnotationManager? _markersManager;
  PolylineAnnotationManager? _polylineManager;

  final _directionsService = DirectionsService();
  late final Widget _mapWidget;
  bool _isRecentering = false;

  late final double _initialCenterLat;
  late final double _initialCenterLng;

  @override
  void initState() {
    super.initState();
    _initialCenterLat = widget.pickupLat ??
        widget.driverLat ??
        widget.dropoffLat ??
        _fallbackLat;
    _initialCenterLng = widget.pickupLng ??
        widget.driverLng ??
        widget.dropoffLng ??
        _fallbackLng;

    _mapWidget = MapWidget(
      key: const ValueKey('ride_tracking_map_instance'),
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(_initialCenterLng, _initialCenterLat),
        ),
        zoom: 14.5,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));

    _markersManager =
        await controller.annotations.createCircleAnnotationManager();
    _polylineManager =
        await controller.annotations.createPolylineAnnotationManager();

    await _drawRouteAndMarkers();
  }

  @override
  void didUpdateWidget(RideTrackingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.dropoffLat != widget.dropoffLat ||
        oldWidget.dropoffLng != widget.dropoffLng ||
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng) {
      _drawRouteAndMarkers();
    }
  }

  Future<void> _drawRouteAndMarkers() async {
    final markerManager = _markersManager;
    final polyManager = _polylineManager;
    if (markerManager == null || polyManager == null) return;

    await markerManager.deleteAll();
    await polyManager.deleteAll();

    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.dropoffLat;
    final dLng = widget.dropoffLng;
    final drvLat = widget.driverLat;
    final drvLng = widget.driverLng;

    // 1. Draw Pickup Pin (Emerald Green #10B981)
    if (pLat != null && pLng != null) {
      final point = Point(coordinates: Position(pLng, pLat));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 14.0,
        circleColor: const Color(0xFF10B981).withValues(alpha: 0.25).toARGB32(),
        circleStrokeWidth: 0,
      ));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 8.0,
        circleColor: const Color(0xFF10B981).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }

    // 2. Draw Drop-off Pin (Red #EF4444)
    if (dLat != null && dLng != null) {
      final point = Point(coordinates: Position(dLng, dLat));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 14.0,
        circleColor: const Color(0xFFEF4444).withValues(alpha: 0.25).toARGB32(),
        circleStrokeWidth: 0,
      ));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 8.0,
        circleColor: const Color(0xFFEF4444).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }

    // 3. Draw Driver Pin (Amber/Yellow #F59E0B)
    if (drvLat != null && drvLng != null) {
      final point = Point(coordinates: Position(drvLng, drvLat));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 18.0,
        circleColor: const Color(0xFFF59E0B).withValues(alpha: 0.3).toARGB32(),
        circleStrokeWidth: 0,
      ));
      await markerManager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 9.0,
        circleColor: const Color(0xFFF59E0B).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }

    // 4. Draw Route Directions Polyline
    final startLat = drvLat ?? pLat;
    final startLng = drvLng ?? pLng;
    final targetLat = dLat ?? pLat;
    final targetLng = dLng ?? pLng;

    if (startLat != null &&
        startLng != null &&
        targetLat != null &&
        targetLng != null &&
        (startLat != targetLat || startLng != targetLng)) {
      final route = await _directionsService.getRoute(
        pickupLat: startLat,
        pickupLng: startLng,
        dropoffLat: targetLat,
        dropoffLng: targetLng,
      );

      if (route != null && route.coordinates.length >= 2) {
        // Casing / Glow
        await polyManager.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: route.coordinates),
          lineColor: const Color(0xFF1E40AF).withValues(alpha: 0.35).toARGB32(),
          lineWidth: 7.5,
          lineJoin: LineJoin.ROUND,
        ));

        // Main line
        await polyManager.create(PolylineAnnotationOptions(
          geometry: LineString(coordinates: route.coordinates),
          lineColor: const Color(0xFF2563EB).toARGB32(),
          lineWidth: 4.5,
          lineJoin: LineJoin.ROUND,
        ));
      }

      _frameCoordinates([
        Position(startLng, startLat),
        Position(targetLng, targetLat),
      ]);
    }
  }

  void _frameCoordinates(List<Position> points) {
    final controller = _controller;
    if (controller == null || points.length < 2) return;

    final p1 = points[0];
    final p2 = points[1];
    final centerLat = (p1.lat.toDouble() + p2.lat.toDouble()) / 2;
    final centerLng = (p1.lng.toDouble() + p2.lng.toDouble()) / 2;
    final distKm = haversineKm(
      p1.lat.toDouble(),
      p1.lng.toDouble(),
      p2.lat.toDouble(),
      p2.lng.toDouble(),
    );

    double zoom;
    if (distKm < 0.8) {
      zoom = 15.5;
    } else if (distKm < 2.0) {
      zoom = 14.5;
    } else if (distKm < 5.0) {
      zoom = 13.5;
    } else if (distKm < 10.0) {
      zoom = 12.5;
    } else {
      zoom = 11.0;
    }

    controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 900),
    );
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
        await controller.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 15.5,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _isRecentering = false);
  }

  @override
  Widget build(BuildContext context) {
    final distance = widget.distanceKm != null
        ? '${widget.distanceKm!.toStringAsFixed(1)} km'
        : '1.2 km';

    return Stack(
      children: [
        Positioned.fill(
          child: _mapWidget,
        ),

        // Distance to destination badge (matching HTML design)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const Text(
                    'to destination',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Recenter Button
        Positioned(
          right: 16,
          bottom: widget.bottomOffset ?? 340,
          child: MapRecenterButton(
            onPressed: _recenterOnGps,
            isLoading: _isRecentering,
            color: const Color(0xFF2563EB),
          ),
        ),
      ],
    );
  }
}
