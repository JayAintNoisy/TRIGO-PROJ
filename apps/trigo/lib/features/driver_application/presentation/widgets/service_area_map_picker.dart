import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../../shared/utils/municipality_locator.dart';
import '../../../../shared/widgets/map_recenter_button.dart';

/// Interactive Mapbox picker for driver onboarding: lets the applicant drag the
/// map under a fixed center pin to choose their home municipality.
class ServiceAreaMapPicker extends StatefulWidget {
  const ServiceAreaMapPicker({
    super.key,
    required this.municipalities,
    required this.onChanged,
    this.initialCenterLat,
    this.initialCenterLng,
    this.initialMunicipalityId,
    this.initialPosition,
  });

  final List<dynamic> municipalities;
  final ValueChanged<MunicipalityMatch?> onChanged;
  final double? initialCenterLat;
  final double? initialCenterLng;
  final String? initialMunicipalityId;
  final geo.Position? initialPosition;

  @override
  State<ServiceAreaMapPicker> createState() => _ServiceAreaMapPickerState();
}

class _ServiceAreaMapPickerState extends State<ServiceAreaMapPicker> {
  static const _fallbackLat = 8.1575;
  static const _fallbackLng = 125.1278;

  MapboxMap? _controller;
  MunicipalityMatch? _match;
  double? _startLat;
  double? _startLng;
  bool _isLocating = true;
  bool _isRequestingLocation = false;

  @override
  void initState() {
    super.initState();
    _initStartPosition();
  }

  Future<void> _initStartPosition() async {
    double? lat = widget.initialCenterLat;
    double? lng = widget.initialCenterLng;

    final initialId = widget.initialMunicipalityId;
    if ((lat == null || lng == null) && initialId != null) {
      for (final m in widget.municipalities) {
        if (m is Map && m['id'] == initialId) {
          lat = (m['centerLat'] as num?)?.toDouble();
          lng = (m['centerLng'] as num?)?.toDouble();
          _match = matchFromMunicipalityMap(m);
          break;
        }
      }
    }
    if (lat == null || lng == null) {
      final pos = widget.initialPosition ??
          await _getCurrentPosition().timeout(
            const Duration(seconds: 6),
            onTimeout: () => null,
          );
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    }
    if (!mounted) return;
    setState(() {
      _startLat = lat ?? _fallbackLat;
      _startLng = lng ?? _fallbackLng;
      _isLocating = false;
    });
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
    if (_controller == null || _isRequestingLocation) return;
    setState(() => _isRequestingLocation = true);
    final pos = await _getCurrentPosition();
    if (!mounted) return;
    setState(() => _isRequestingLocation = false);
    if (pos == null) return;
    await _controller!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(pos.longitude, pos.latitude),
        ),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));

    // Recenter map once loaded
    final pos = widget.initialPosition ?? await _getCurrentPosition();
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

  Future<void> _handleMapIdle(MapIdleEventData _) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final state = await controller.getCameraState();
    final coordinates = state.center.coordinates;
    final match = locateMunicipality(
      coordinates.lat.toDouble(),
      coordinates.lng.toDouble(),
      widget.municipalities,
    );
    if (!mounted) return;
    final changed = match?.id != _match?.id;
    setState(() => _match = match);
    if (changed) {
      widget.onChanged(match);
    }
  }

  Widget _buildStatusBanner() {
    final theme = Theme.of(context);
    final matched = _match != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFECFDF5) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: matched ? const Color(0xFFA7F3D0) : const Color(0xFFFED7AA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            matched ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color:
                matched ? const Color(0xFF059669) : const Color(0xFFEA580C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              matched
                  ? 'Service municipality: '
                      '${_match!.name}${_match!.province != null ? ', ${_match!.province}' : ''}'
                  : 'Outside service areas \u2014 drag the map so the pin '
                      'sits inside your municipality.',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: matched
                    ? const Color(0xFF065F46)
                    : const Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Municipality',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF475569),
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: _isLocating
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      MapWidget(
                        key: const ValueKey('service_area_picker_map'),
                        viewport: CameraViewportState(
                          center: Point(
                            coordinates: Position(_startLng!, _startLat!),
                          ),
                          zoom: 14.5,
                        ),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        onMapCreated: _onMapCreated,
                        onMapIdleListener: _handleMapIdle,
                      ),
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(
                            Icons.location_on,
                            size: 40,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: MapRecenterButton(
                          onPressed: _recenterOnGps,
                          isLoading: _isRequestingLocation,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        _buildStatusBanner(),
      ],
    );
  }
}
