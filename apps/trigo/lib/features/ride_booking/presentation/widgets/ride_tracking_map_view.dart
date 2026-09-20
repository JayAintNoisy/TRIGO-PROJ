import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../shared/services/directions_service.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../../shared/widgets/map_recenter_button.dart';

/// Full-screen Mapbox map for ride tracking with optimized route caching,
/// live driver pin updates without redundant Directions API calls,
/// and local distance estimation.
///
/// Markers are drawn as distinct glyphs so each role is identifiable at a
/// glance: a car for the driver, a person for the passenger pickup, and a
/// flag for the drop-off.
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
    this.rideStatus,
    this.ownLat,
    this.ownLng,
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

  /// Current ride status. Drives which leg is routed: the driver heads to the
  /// passenger while the ride is accepted/driver_arriving, and to the drop-off
  /// once the trip is in progress.
  final String? rideStatus;

  /// The viewing device's own live position. Used to centre the camera on
  /// "where I am" when the map opens, rather than on the midpoint of every
  /// tracked point (which drifts toward the far-away drop-off).
  final double? ownLat;
  final double? ownLng;

  @override
  State<RideTrackingMapView> createState() => _RideTrackingMapViewState();
}

/// How far the driver must move before the route polyline is re-fetched.
///
/// Deliberately equal to the driver's position-broadcast distance filter
/// (see `_broadcastDistanceFilterMeters` in ride_tracking_screen.dart) so the
/// drawn line and the uploaded position advance in step. If one were larger,
/// it would visibly lag the other.
const double routeRefreshDistanceKm = 0.05; // 50 m

/// True while the driver is still travelling to the passenger.
///
/// Exposed (not private) so tests can pin the status vocabulary the map keys
/// off; a rename on either side then fails loudly instead of silently
/// reverting the map to a two-point route.
@visibleForTesting
bool isPickupLegStatus(String? status) =>
    status == 'accepted' || status == 'driver_arriving';

bool _isPickupLeg(String? status) => isPickupLegStatus(status);

class _RideTrackingMapViewState extends State<RideTrackingMapView> {
  static const _fallbackLat = 8.1575;
  static const _fallbackLng = 125.1278;

  // Marker palette, kept distinct from the route line.
  static const _driverColor = Color(0xFFF59E0B); // amber
  static const _pickupColor = Color(0xFF10B981); // emerald
  static const _dropoffColor = Color(0xFFEF4444); // red

  // Maki glyphs bundled with the Mapbox Streets style. The coloured circle
  // underneath each marker is what guarantees a visible, role-distinct point;
  // the glyph and its label are layered on top, so a style that lacks a given
  // icon still shows a correctly coloured pin with a text label.
  //
  // Maki has no rickshaw/tricycle glyph, so 'scooter' stands in for the
  // driver's vehicle as the closest small local transport icon.
  static const _driverIcon = 'scooter-15';
  static const _passengerIcon = 'marker-15';

  /// Label for the signed-in user's own marker.
  static const _meLabel = 'Me';

  /// Label for the other party: a passenger sees "Driver", a driver sees
  /// "Passenger".
  String get _counterpartLabel => widget.isDriver ? 'Passenger' : 'Driver';

  MapboxMap? _controller;
  CircleAnnotationManager? _staticMarkersManager;
  CircleAnnotationManager? _driverMarkerManager;
  PointAnnotationManager? _iconManager;
  PolylineAnnotationManager? _polylineManager;

  final _directionsService = DirectionsService();
  late final Widget _mapWidget;
  bool _isRecentering = false;
  bool _isFetchingRoute = false;

  /// Guards the one-shot "centre on my location" behaviour that runs when the
  /// map opens. After that the camera belongs to the user.
  bool _hasFramedInitialView = false;

  late final double _initialCenterLat;
  late final double _initialCenterLng;

  // Cached route coordinates to avoid billable API requests on every driver move
  List<Position>? _cachedRouteCoordinates;
  double? _cachedStartLat;
  double? _cachedStartLng;
  double? _cachedTargetLat;
  double? _cachedTargetLng;

  @override
  void initState() {
    super.initState();
    // The initial viewport is a placeholder until a real fix arrives; prefer
    // the viewer's own position, then the driver, then the pickup.
    _initialCenterLat = widget.ownLat ??
        (widget.isDriver ? widget.driverLat : widget.pickupLat) ??
        widget.driverLat ??
        widget.pickupLat ??
        widget.dropoffLat ??
        _fallbackLat;
    _initialCenterLng = widget.ownLng ??
        (widget.isDriver ? widget.driverLng : widget.pickupLng) ??
        widget.driverLng ??
        widget.pickupLng ??
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

    _startFallbackAnchorTimer();
  }

  /// The two points the camera should frame for the leg being travelled.
  ///
  /// - Heading to the passenger: the driver's live position and the pickup
  ///   (which is where the passenger is waiting).
  /// - Trip under way: the driver's live position and the drop-off.
  ///
  /// The drop-off is deliberately absent from the pickup leg so a distant
  /// destination cannot drag the centre or force a wide zoom while the driver
  /// and passenger are still meeting up.
  List<Position> _activeLegPoints() {
    final headingToPickup = _isPickupLeg(widget.rideStatus);

    // The driver's live position is the moving end of either leg.
    final driverPoint = (widget.driverLat != null && widget.driverLng != null)
        ? Position(widget.driverLng!, widget.driverLat!)
        : null;

    if (headingToPickup) {
      final pickupPoint = (widget.pickupLat != null && widget.pickupLng != null)
          ? Position(widget.pickupLng!, widget.pickupLat!)
          : null;
      return <Position>[
        if (driverPoint != null) driverPoint,
        if (pickupPoint != null) pickupPoint,
      ];
    }

    final dropoffPoint =
        (widget.dropoffLat != null && widget.dropoffLng != null)
            ? Position(widget.dropoffLng!, widget.dropoffLat!)
            : null;
    return <Position>[
      if (driverPoint != null) driverPoint,
      if (dropoffPoint != null) dropoffPoint,
    ];
  }

  /// Frames the two points of the leg being travelled: the current starting
  /// point and the leg's destination.
  ///
  /// - Heading to the passenger: driver's live position <-> pickup.
  /// - Trip under way: driver's live position <-> drop-off.
  ///
  /// The camera centres on the midpoint of those two and zooms to fit them, so
  /// both ends are visible. Nothing else is included — in particular the
  /// drop-off is excluded from the pickup leg, so a distant destination cannot
  /// drag the centre away or force a wide zoom.
  void _fitToKnownPoints() {
    final controller = _controller;
    if (controller == null) return;

    final points = _activeLegPoints();
    if (points.isEmpty) return;

    if (points.length == 1) {
      // Only one end known: centre on it rather than fitting a zero span.
      controller.flyTo(
        CameraOptions(center: Point(coordinates: points.first), zoom: 15.0),
        MapAnimationOptions(duration: 700),
      );
      return;
    }

    final a = points.first;
    final b = points.last;
    final centerLat = (a.lat.toDouble() + b.lat.toDouble()) / 2;
    final centerLng = (a.lng.toDouble() + b.lng.toDouble()) / 2;
    final spanKm = haversineKm(
      a.lat.toDouble(),
      a.lng.toDouble(),
      b.lat.toDouble(),
      b.lng.toDouble(),
    );

    controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(centerLng, centerLat)),
        zoom: _zoomForSpan(spanKm),
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  /// Zoom level that comfortably fits a leg of [spanKm].
  static double _zoomForSpan(double spanKm) {
    if (spanKm < 0.8) return 15.5;
    if (spanKm < 2.0) return 14.5;
    if (spanKm < 5.0) return 13.5;
    if (spanKm < 10.0) return 12.5;
    return 11.0;
  }

  /// Frames the active leg once the data needed to do so is available.
  ///
  /// Waits briefly for the viewer's own GPS fix, because for a driver that fix
  /// is one end of the leg being framed; latching on the fallback immediately
  /// would frame the leg before the driver's real position is known.
  void _maybeFitInitialView() {
    if (_hasFramedInitialView || _controller == null) return;

    final hasOwnFix = widget.ownLat != null && widget.ownLng != null;
    if (!hasOwnFix && !_allowFallbackAnchor) return;
    if (_activeLegPoints().isEmpty) return;

    _hasFramedInitialView = true;
    _fitToKnownPoints();
  }

  /// Set once a short grace period has elapsed, after which the map will frame
  /// using a fallback anchor (pickup or driver position) because no own fix
  /// arrived. Without this the map would stay on its initial viewport
  /// indefinitely when location permission is denied.
  bool _allowFallbackAnchor = false;

  void _startFallbackAnchorTimer() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || _hasFramedInitialView) return;
      _allowFallbackAnchor = true;
      _maybeFitInitialView();
    });
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));

    // Managers are painted in creation order, so the polyline is created first
    // to keep the route line *underneath* the location markers and labels.
    _polylineManager =
        await controller.annotations.createPolylineAnnotationManager();
    _staticMarkersManager =
        await controller.annotations.createCircleAnnotationManager();
    _driverMarkerManager =
        await controller.annotations.createCircleAnnotationManager();
    _iconManager = await controller.annotations.createPointAnnotationManager();

    await _drawStaticPins();
    await _updateDriverMarker();
    await _fetchAndDrawRouteIfNeeded();
    // Fit after the initial draw so the camera lands on real coordinates
    // instead of the fallback centroid.
    _maybeFitInitialView();
  }

  @override
  void didUpdateWidget(RideTrackingMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final staticEndpointsChanged = oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.dropoffLat != widget.dropoffLat ||
        oldWidget.dropoffLng != widget.dropoffLng;

    final driverMoved = oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng;

    // A status change switches the routed leg (to pickup vs to drop-off).
    final legChanged =
        _isPickupLeg(oldWidget.rideStatus) != _isPickupLeg(widget.rideStatus);

    if (staticEndpointsChanged || legChanged) {
      _drawStaticPins();
      _fetchAndDrawRouteIfNeeded(force: true);
      // Note: the camera is intentionally NOT re-framed here. A status change
      // mid-ride must not move the map out from under the user; they can use
      // the recenter or fit buttons if they want the new leg in view.
    }

    if (driverMoved) {
      // Move driver marker locally without requesting the Directions API
      _updateDriverMarker();
      _drawStaticPins();

      // Re-route as the driver advances. Previously this only fired when no
      // route was cached at all, so once a line existed it froze at the
      // driver's first position. _fetchAndDrawRouteIfNeeded now decides
      // whether the movement justifies a new Directions request.
      if (_isPickupLeg(widget.rideStatus)) {
        _fetchAndDrawRouteIfNeeded();
      }
    }

    // The camera is only framed once, on open. Later driver updates move the
    // marker and the route line but never yank the camera, so panning and
    // zooming are not fought by the map.
    _maybeFitInitialView();
  }

  /// Draws the passenger pickup and drop-off markers plus their icons.
  ///
  /// While the driver is still heading to the pickup, the drop-off is drawn
  /// dimmed because it is not the active destination yet.
  Future<void> _drawStaticPins() async {
    final manager = _staticMarkersManager;
    final icons = _iconManager;
    if (manager == null || !mounted) return;

    await manager.deleteAll();
    await icons?.deleteAll();

    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.dropoffLat;
    final dLng = widget.dropoffLng;
    final headingToPickup = _isPickupLeg(widget.rideStatus);

    // 1. Passenger pickup (Emerald). Highlighted while it is the destination.
    if (pLat != null && pLng != null) {
      final point = Point(coordinates: Position(pLng, pLat));
      final alpha = headingToPickup ? 0.30 : 0.18;
      await manager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 16.0,
        circleColor: _pickupColor.withValues(alpha: alpha).toARGB32(),
        circleStrokeWidth: 0,
      ));
      await manager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 9.0,
        circleColor: _pickupColor.toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: 1.0,
      ));
      await icons?.create(PointAnnotationOptions(
        geometry: point,
        iconImage: _passengerIcon,
        iconSize: 1.4,
        iconColor: _pickupColor.toARGB32(),
        // The pickup is where the passenger is: "Me" for a passenger,
        // "Passenger" for the driver.
        textField: widget.isDriver ? 'Passenger' : _meLabel,
        textSize: 11,
        textColor: Colors.white.toARGB32(),
        textHaloColor: _pickupColor.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: const [0.0, 1.6],
      ));
    }

    // 2. Passenger drop-off (Red). Dimmed until the trip is under way.
    if (dLat != null && dLng != null) {
      final point = Point(coordinates: Position(dLng, dLat));
      final alpha = headingToPickup ? 0.14 : 0.30;
      final coreAlpha = headingToPickup ? 0.45 : 1.0;
      await manager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 16.0,
        circleColor: _dropoffColor.withValues(alpha: alpha).toARGB32(),
        circleStrokeWidth: 0,
      ));
      await manager.create(CircleAnnotationOptions(
        geometry: point,
        circleRadius: 9.0,
        circleColor: _dropoffColor.withValues(alpha: coreAlpha).toARGB32(),
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.5,
        circleStrokeOpacity: headingToPickup ? 0.5 : 1.0,
      ));
      await icons?.create(PointAnnotationOptions(
        geometry: point,
        iconImage: _passengerIcon,
        iconSize: 1.4,
        iconColor: _dropoffColor.toARGB32(),
        iconOpacity: headingToPickup ? 0.55 : 1.0,
        textField: 'Drop-off',
        textSize: 11,
        textColor: Colors.white.toARGB32(),
        textHaloColor: _dropoffColor.toARGB32(),
        textHaloWidth: 1.5,
        textOffset: const [0.0, 1.6],
      ));
    }
  }

  /// Updates the Driver Pin (Amber) smoothly in memory.
  Future<void> _updateDriverMarker() async {
    final manager = _driverMarkerManager;
    final icons = _iconManager;
    final drvLat = widget.driverLat;
    final drvLng = widget.driverLng;

    if (manager == null || drvLat == null || drvLng == null || !mounted) return;

    await manager.deleteAll();

    final point = Point(coordinates: Position(drvLng, drvLat));

    // Outer glow pulse
    await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 20.0,
      circleColor: _driverColor.withValues(alpha: 0.3).toARGB32(),
      circleStrokeWidth: 0,
    ));

    // Core driver dot
    await manager.create(CircleAnnotationOptions(
      geometry: point,
      circleRadius: 10.0,
      circleColor: _driverColor.toARGB32(),
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 2.5,
      circleStrokeOpacity: 1.0,
    ));

    // Driver glyph + label so the driver is distinguishable from the passenger.
    // It reads "Me" on the driver's own device and "Driver" on the passenger's.
    await icons?.create(PointAnnotationOptions(
      geometry: point,
      iconImage: _driverIcon,
      iconSize: 1.5,
      iconColor: _driverColor.toARGB32(),
      textField: widget.isDriver ? _meLabel : _counterpartLabel,
      textSize: 11,
      textColor: Colors.white.toARGB32(),
      textHaloColor: _driverColor.toARGB32(),
      textHaloWidth: 1.5,
      textOffset: const [0.0, 1.7],
    ));
  }

  /// Fetches the active leg's route polyline ONCE and caches it.
  ///
  /// While the driver is en route to the passenger the leg is driver->pickup;
  /// once the trip is in progress it becomes pickup->drop-off.
  Future<void> _fetchAndDrawRouteIfNeeded({bool force = false}) async {
    final polyManager = _polylineManager;
    if (polyManager == null || _isFetchingRoute || !mounted) return;

    final headingToPickup = _isPickupLeg(widget.rideStatus);

    double? startLat;
    double? startLng;
    double? targetLat;
    double? targetLng;

    if (headingToPickup) {
      startLat = widget.driverLat;
      startLng = widget.driverLng;
      targetLat = widget.pickupLat;
      targetLng = widget.pickupLng;
      // Without a driver fix yet, fall back to pickup as a stable start.
      startLat ??= widget.pickupLat;
      startLng ??= widget.pickupLng;
    } else {
      startLat = widget.pickupLat;
      startLng = widget.pickupLng;
      targetLat = widget.dropoffLat;
      targetLng = widget.dropoffLng;
    }

    if (startLat == null ||
        startLng == null ||
        targetLat == null ||
        targetLng == null) {
      return;
    }

    if (startLat == targetLat && startLng == targetLng) return;

    // Reuse the cached line unless the driver has drifted far enough from the
    // route's start to make it visibly stale.
    if (!force &&
        _cachedRouteCoordinates != null &&
        _cachedTargetLat == targetLat &&
        _cachedTargetLng == targetLng) {
      if (_cachedStartLat != null && _cachedStartLng != null) {
        final startDeviationKm =
            haversineKm(_cachedStartLat!, _cachedStartLng!, startLat, startLng);
        if (startDeviationKm < routeRefreshDistanceKm) {
          return; // Reuse cached route
        }
      }
    }

    _isFetchingRoute = true;

    try {
      final route = await _directionsService.getRoute(
        pickupLat: startLat,
        pickupLng: startLng,
        dropoffLat: targetLat,
        dropoffLng: targetLng,
      );

      if (!mounted) return;

      if (route != null && route.coordinates.length >= 2) {
        _cachedRouteCoordinates = route.coordinates;
        _cachedStartLat = startLat;
        _cachedStartLng = startLng;
        _cachedTargetLat = targetLat;
        _cachedTargetLng = targetLng;

        await polyManager.deleteAll();

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

        // The camera is intentionally NOT moved here. The route refreshes
        // every 50m as the driver moves, so auto-framing on each fetch would
        // yank the map constantly and fight the user. Framing happens once on
        // open, then only when the fit/recenter buttons are tapped.
      }
    } catch (_) {
      // Handle network issue gracefully
    } finally {
      _isFetchingRoute = false;
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

  /// The two distances that matter to the current user, as straight-line
  /// (haversine) values so no extra Directions API calls are billed.
  ///
  /// - Driver: how far to the passenger, and the full remaining trip
  ///   (driver -> passenger -> destination).
  /// - Passenger: how far the driver still is, and how far they themselves
  ///   still have to travel (passenger -> destination).
  ///
  /// Returns nulls when coordinates are missing so the badge can hide itself
  /// rather than show a fabricated placeholder.
  ({
    double? primaryKm,
    String? primaryLabel,
    double? secondaryKm,
    String? secondaryLabel
  }) _remainingDistances() {
    final drvLat = widget.driverLat;
    final drvLng = widget.driverLng;
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.dropoffLat;
    final dLng = widget.dropoffLng;

    final hasDriver = drvLat != null && drvLng != null;
    final hasPickup = pLat != null && pLng != null;
    final hasDropoff = dLat != null && dLng != null;

    final toPickup =
        hasDriver && hasPickup ? haversineKm(drvLat, drvLng, pLat, pLng) : null;
    final pickupToDropoff =
        hasPickup && hasDropoff ? haversineKm(pLat, pLng, dLat, dLng) : null;

    if (widget.isDriver) {
      // Driver -> passenger, then the whole remaining trip.
      final totalTrip = (toPickup != null && pickupToDropoff != null)
          ? toPickup + pickupToDropoff
          : null;
      return (
        primaryKm: toPickup,
        primaryLabel: 'To passenger',
        secondaryKm: totalTrip,
        secondaryLabel: 'Total trip',
      );
    }

    // Passenger -> driver, then their own remaining journey.
    return (
      primaryKm: toPickup,
      primaryLabel: 'Driver distance',
      secondaryKm: pickupToDropoff,
      secondaryLabel: 'To destination',
    );
  }

  String? _formatKm(double? km) =>
      km == null ? null : '${km.toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final distances = _remainingDistances();
    final primaryText = _formatKm(distances.primaryKm);
    final secondaryText = _formatKm(distances.secondaryKm);
    final primaryLabel = distances.primaryLabel;
    final secondaryLabel = distances.secondaryLabel;

    return Stack(
      children: [
        Positioned.fill(
          child: _mapWidget,
        ),

        // Remaining-distance badge. Shows two role-aware figures: what the
        // current leg costs, and what the rest of the journey costs.
        if (primaryText != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DistanceFigure(
                      km: primaryText,
                      label: primaryLabel!,
                      valueColor: const Color(0xFF2563EB),
                    ),
                    if (secondaryText != null) ...[
                      Container(
                        width: 1,
                        height: 30,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.grey.shade200,
                      ),
                      _DistanceFigure(
                        km: secondaryText,
                        label: secondaryLabel!,
                        valueColor: const Color(0xFF0F172A),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // Map controls, stacked above the bottom sheet. `bottomOffset` is the
        // measured sheet height, so these never end up hidden behind it.
        Positioned(
          right: 16,
          bottom: (widget.bottomOffset ?? 340) + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapRecenterButton(
                onPressed: _recenterOnGps,
                isLoading: _isRecentering,
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 10),
              // Fit every tracked point (driver, pickup, drop-off) back into
              // view — the fastest way to recover after panning away.
              MapRecenterButton(
                onPressed: _fitToKnownPoints,
                color: const Color(0xFF0F172A),
                icon: Icons.zoom_out_map,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One distance figure inside the remaining-distance badge.
class _DistanceFigure extends StatelessWidget {
  const _DistanceFigure({
    required this.km,
    required this.label,
    required this.valueColor,
  });

  final String km;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          km,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
