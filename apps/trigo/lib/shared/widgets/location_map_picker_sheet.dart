import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/geocoding_service.dart';
import 'map_recenter_button.dart';

/// Modal bottom sheet that lets users pinpoint an exact address on a Mapbox map.
class LocationMapPickerSheet extends StatefulWidget {
  const LocationMapPickerSheet({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
    this.pinColor = const Color(0xFF2563EB),
  });

  final String title;
  final double? initialLat;
  final double? initialLng;
  final Color pinColor;

  static Future<LocationSearchResult?> show(
    BuildContext context, {
    required String title,
    double? initialLat,
    double? initialLng,
    Color pinColor = const Color(0xFF2563EB),
  }) {
    return showModalBottomSheet<LocationSearchResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationMapPickerSheet(
        title: title,
        initialLat: initialLat,
        initialLng: initialLng,
        pinColor: pinColor,
      ),
    );
  }

  @override
  State<LocationMapPickerSheet> createState() => _LocationMapPickerSheetState();
}

class _LocationMapPickerSheetState extends State<LocationMapPickerSheet> {
  static const _defaultLat = 8.1575; // Bukidnon
  static const _defaultLng = 125.1278;

  MapboxMap? _controller;
  final _geocodingService = GeocodingService();

  late final double _startLat;
  late final double _startLng;
  late final Widget _mapWidget;

  double _currentLat = _defaultLat;
  double _currentLng = _defaultLng;
  Timer? _debounceTimer;

  // Dedicated value notifiers so state changes NEVER trigger MapWidget rebuilds
  final _addressNotifier = ValueNotifier<String>('Locating...');
  final _isGeocodingNotifier = ValueNotifier<bool>(true);
  final _isRecenteringNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _startLat = widget.initialLat ?? _defaultLat;
    _startLng = widget.initialLng ?? _defaultLng;
    _currentLat = _startLat;
    _currentLng = _startLng;
    _resolveAddress(_currentLat, _currentLng);

    // Initialized once with viewport state so Flutter widget rebuilds never reset the camera
    _mapWidget = MapWidget(
      key: const ValueKey('location_picker_map_instance'),
      viewport: CameraViewportState(
        center: Point(coordinates: Position(_startLng, _startLat)),
        zoom: 15.5,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
      onCameraChangeListener: _onCameraChanged,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressNotifier.dispose();
    _isGeocodingNotifier.dispose();
    _isRecenteringNotifier.dispose();
    super.dispose();
  }

  Future<void> _resolveAddress(double lat, double lng) async {
    _isGeocodingNotifier.value = true;
    try {
      final address = await _geocodingService.reverseGeocode(lat, lng);
      if (mounted) {
        _addressNotifier.value = address;
      }
    } catch (_) {
      if (mounted) {
        _addressNotifier.value =
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
    } finally {
      if (mounted) {
        _isGeocodingNotifier.value = false;
      }
    }
  }

  void _onCameraChanged(CameraChangedEventData event) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final controller = _controller;
      if (controller == null || !mounted) return;
      try {
        final state = await controller.getCameraState();
        final center = state.center;
        final newLat = center.coordinates.lat.toDouble();
        final newLng = center.coordinates.lng.toDouble();

        // Only reverse geocode if the center moved significantly
        if ((newLat - _currentLat).abs() > 0.00005 ||
            (newLng - _currentLng).abs() > 0.00005) {
          _currentLat = newLat;
          _currentLng = newLng;
          await _resolveAddress(_currentLat, _currentLng);
        }
      } catch (_) {}
    });
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _controller = controller;
    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));
  }

  Future<void> _recenterOnGps() async {
    if (_isRecenteringNotifier.value) return;
    _isRecenteringNotifier.value = true;
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 6));
      _currentLat = pos.latitude;
      _currentLng = pos.longitude;
      final controller = _controller;
      if (controller != null) {
        await controller.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(_currentLng, _currentLat)),
            zoom: 15.5,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
      await _resolveAddress(_currentLat, _currentLng);
    } catch (_) {}
    if (mounted) _isRecenteringNotifier.value = false;
  }

  void _confirm() {
    final addr = _addressNotifier.value;
    Navigator.of(context).pop(LocationSearchResult(
      title: addr.split(',').first.trim(),
      subtitle: addr.contains(',')
          ? addr.substring(addr.indexOf(',') + 1).trim()
          : '',
      latitude: _currentLat,
      longitude: _currentLng,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Cached MapWidget instance preventing any camera reset on rebuild
          Positioned.fill(
            child: _mapWidget,
          ),

          // Fixed Center Pin
          Center(
            child: IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Set location here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.location_on,
                      color: widget.pinColor,
                      size: 42,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.place, color: widget.pinColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),

          // Recenter Button
          Positioned(
            right: 16,
            bottom: 170,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isRecenteringNotifier,
              builder: (context, isRecentering, _) {
                return MapRecenterButton(
                  onPressed: _recenterOnGps,
                  isLoading: isRecentering,
                  color: widget.pinColor,
                );
              },
            ),
          ),

          // Bottom Confirmation Card
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_pin,
                          color: widget.pinColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _isGeocodingNotifier,
                          builder: (context, isGeocoding, _) {
                            if (isGeocoding) {
                              return const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
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
                              valueListenable: _addressNotifier,
                              builder: (context, address, _) {
                                return Text(
                                  address,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isGeocodingNotifier,
                      builder: (context, isGeocoding, _) {
                        return ElevatedButton(
                          onPressed: isGeocoding ? null : _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.pinColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm Location',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
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
