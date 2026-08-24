import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../shared/widgets/map_recenter_button.dart';

/// Full-screen map for the driver home screen: green pickup pins for open ride
/// requests and a blue dot for the driver's own position.
class DriverMapView extends StatefulWidget {
  const DriverMapView({
    super.key,
    required this.municipalities,
    required this.availableRides,
    required this.isOnline,
    this.municipalityId,
    this.currentPosition,
    this.onPickupTapped,
  });

  final List<dynamic> municipalities;
  final List<dynamic> availableRides;
  final bool isOnline;
  final String? municipalityId;

  /// Latest GPS fix from the owning screen (also used for broadcasting).
  final geo.Position? currentPosition;
  final void Function(Map ride)? onPickupTapped;

  @override
  State<DriverMapView> createState() => _DriverMapViewState();
}

class _DriverMapViewState extends State<DriverMapView> {
  // Bukidnon centroid used when GPS and municipality center are unavailable
  static const _fallbackLat = 8.1575;
  static const _fallbackLng = 125.1278;
  static const _pickupLayerId = 'trigo-pickup-pins';

  MapboxMap? _controller;
  CircleAnnotationManager? _pickupManager;
  CircleAnnotationManager? _locationManager;
  CircleAnnotation? _ownLocationAnnotation;
  final Map<String, Map> _rideByAnnotationId = {};

  double? _startLat;
  double? _startLng;
  bool _isRecentering = false;

  @override
  void initState() {
    super.initState();
    _resolveStartPosition();
  }

  @override
  void didUpdateWidget(DriverMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.availableRides, widget.availableRides) ||
        oldWidget.isOnline != widget.isOnline) {
      _syncPickupAnnotations();
    }
    if (oldWidget.currentPosition != widget.currentPosition) {
      _updateOwnLocation();
      if (oldWidget.currentPosition == null && widget.currentPosition != null) {
        _recenterOnGps();
      }
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  Future<void> _resolveStartPosition() async {
    final pos = await _getCurrentPosition().timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );
    if (!mounted) return;
    final muni = _driverMunicipality();
    final newLat = pos?.latitude ??
        ((muni?['centerLat'] as num?)?.toDouble() ?? _fallbackLat);
    final newLng = pos?.longitude ??
        ((muni?['centerLng'] as num?)?.toDouble() ?? _fallbackLng);
    setState(() {
      _startLat = newLat;
      _startLng = newLng;
    });
    if (pos != null && _controller != null) {
      _controller?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  Map? _driverMunicipality() {
    final id = widget.municipalityId;
    if (id == null) return null;
    for (final m in widget.municipalities) {
      if (m is Map && m['id'] == id) return m;
    }
    return null;
  }

  Future<geo.Position?> _getCurrentPosition() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever ||
          !await geo.Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _recenterOnGps() async {
    final controller = _controller;
    if (controller == null || _isRecentering) return;
    setState(() => _isRecentering = true);
    var pos = widget.currentPosition ?? await _getCurrentPosition();
    if (!mounted) return;
    setState(() => _isRecentering = false);
    pos ??= await _getCurrentPosition().timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );
    if (pos == null || controller != _controller) return;
    await controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));

    _pickupManager = await controller.annotations
        .createCircleAnnotationManager(id: _pickupLayerId);
    _locationManager =
        await controller.annotations.createCircleAnnotationManager();
    controller.addInteraction(
      TapInteraction(
        FeaturesetDescriptor(layerId: _pickupLayerId),
        _handlePickupTap,
      ),
    );
    await _syncPickupAnnotations();
    if (widget.currentPosition != null) {
      await _updateOwnLocation();
    }

    // Recenter map once loaded
    final pos = widget.currentPosition ?? await _getCurrentPosition();
    if (pos != null) {
      await controller.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  void _handlePickupTap(
    TypedFeaturesetFeature<FeaturesetDescriptor> feature,
    MapContentGestureContext context,
  ) {
    final id = feature.id?.id;
    if (id == null) return;
    final ride = _rideByAnnotationId[id];
    if (ride != null) {
      widget.onPickupTapped?.call(ride);
    }
  }

  Future<void> _syncPickupAnnotations() async {
    final manager = _pickupManager;
    if (manager == null || !mounted) return;
    await manager.deleteAll();
    _rideByAnnotationId.clear();
    if (!widget.isOnline) return;

    final options = <CircleAnnotationOptions>[];
    final keptRides = <Map>[];
    for (final ride in widget.availableRides) {
      if (ride is! Map) continue;
      final pickupLat = (ride['pickupLat'] as num?)?.toDouble();
      final pickupLng = (ride['pickupLng'] as num?)?.toDouble();
      if (pickupLat == null || pickupLng == null) continue;
      keptRides.add(ride);
      options.add(CircleAnnotationOptions(
        geometry: Point(coordinates: Position(pickupLng, pickupLat)),
        circleRadius: 9,
        circleColor: const Color(0xFF10B981).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
    }
    if (options.isEmpty) return;
    final created = await manager.createMulti(options);
    if (created == null) return;
    for (var i = 0; i < created.length && i < keptRides.length; i++) {
      final ann = created[i];
      if (ann != null) {
        _rideByAnnotationId[ann.id] = keptRides[i];
      }
    }
  }

  Future<void> _updateOwnLocation() async {
    final manager = _locationManager;
    final pos = widget.currentPosition;
    if (manager == null || pos == null || !mounted) return;

    final point = Point(coordinates: Position(pos.longitude, pos.latitude));

    if (_ownLocationAnnotation != null) {
      _ownLocationAnnotation!.geometry = point;
      await manager.update(_ownLocationAnnotation!);
      return;
    }

    // Pulse ring + core dot
    await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 18.0,
      circleColor: const Color(0xFF2563EB).withValues(alpha: 0.18).toARGB32(),
      circleStrokeWidth: 0,
    ));

    _ownLocationAnnotation = await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 8.5,
      circleColor: const Color(0xFF2563EB).toARGB32(),
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeOpacity: 1.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_startLat == null || _startLng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('driver_home_map'),
          viewport: CameraViewportState(
            center: Point(coordinates: Position(_startLng!, _startLat!)),
            zoom: 14.5,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          onMapCreated: _onMapCreated,
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: MapRecenterButton(
            onPressed: _recenterOnGps,
            isLoading: _isRecentering,
          ),
        ),
      ],
    );
  }
}
