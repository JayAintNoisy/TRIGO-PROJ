import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/utils/geo_bounds.dart';
import '../../../../shared/widgets/location_map_picker_sheet.dart';

/// An address input with 450ms debounced geocoding search suggestions and
/// "Select from Map" integration.
///
/// The suggestion list is sized from the space actually available below the
/// field (rather than a fixed height) so landmarks returned by the provider are
/// reachable instead of being clipped, and it shows the place category, the
/// distance when known, and the matched part of the name.
class AddressSearchInput extends StatefulWidget {
  const AddressSearchInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    required this.accentColor,
    this.validator,
    this.proximityLat,
    this.proximityLng,
    this.searchBounds,
    this.onLocationSelected,
    this.onSelectFromMap,
  });

  final TextEditingController controller;
  final String hint;
  final Widget prefixIcon;
  final Color accentColor;
  final String? Function(String?)? validator;
  final double? proximityLat;
  final double? proximityLng;

  /// Fences the search to a geographic box — the TriGo service area — so
  /// in-area landmarks still surface when the user's location is unknown.
  final GeoBounds? searchBounds;
  final ValueChanged<LocationSearchResult>? onLocationSelected;
  final VoidCallback? onSelectFromMap;

  @override
  State<AddressSearchInput> createState() => _AddressSearchInputState();
}

class _AddressSearchInputState extends State<AddressSearchInput> {
  /// Roughly the height of one suggestion row, used to size the list.
  static const double _rowHeight = 62;
  static const double _headerHeight = 42;
  static const double _minOverlayHeight = 140;
  static const int _maxVisibleRows = 6;

  final _geocodingService = GeocodingService();
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<LocationSearchResult> _suggestions = [];
  bool _isSearching = false;
  bool _landmarkSourceFailed = false;

  /// Guards against an older, slower response overwriting a newer one.
  int _searchSequence = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchSequence++;
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay removal slightly so tap events on suggestions can register
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    if (text.trim().length < 3) {
      _searchSequence++;
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _landmarkSourceFailed = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      final sequence = ++_searchSequence;
      setState(() => _isSearching = true);
      _showOverlay();

      final outcome = await _geocodingService.search(
        text,
        proximityLat: widget.proximityLat,
        proximityLng: widget.proximityLng,
        bounds: widget.searchBounds,
      );

      // Ignore a response that a newer keystroke has already superseded.
      if (!mounted || sequence != _searchSequence) return;

      setState(() {
        _suggestions = outcome.results;
        _landmarkSourceFailed = outcome.landmarkSourceFailed;
        _isSearching = false;
      });
      _updateOverlay();
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _updateOverlay();
      return;
    }

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: _layerLink.leaderSize?.width ?? 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, (_layerLink.leaderSize?.height ?? 50) + 4),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _availableOverlayHeight(overlayContext),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  /// Height the suggestion list may occupy before running off-screen or under
  /// the keyboard. Previously a fixed 240px, which fitted barely two rows and
  /// hid the very landmarks the user was searching for.
  double _availableOverlayHeight(BuildContext overlayContext) {
    final media = MediaQuery.of(overlayContext);
    var fieldBottom = media.size.height * 0.35;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      fieldBottom =
          renderObject.localToGlobal(Offset.zero).dy + renderObject.size.height;
    }
    final available =
        media.size.height - fieldBottom - media.viewInsets.bottom - 24;
    final wanted = _headerHeight + _rowHeight * _maxVisibleRows;
    return available.clamp(_minOverlayHeight, wanted).toDouble();
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _select(LocationSearchResult result) {
    widget.controller.text = result.fullAddress;
    widget.onLocationSelected?.call(result);
    _removeOverlay();
    _focusNode.unfocus();
  }

  Widget _buildSuggestionsList() {
    final visible = _suggestions.take(_maxVisibleRows).toList();
    final hiddenCount = _suggestions.length - visible.length;

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        // "Select from Map" Action Header
        InkWell(
          onTap: () {
            _removeOverlay();
            _openMapPicker();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: widget.accentColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(Icons.map, size: 18, color: widget.accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select on map',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: widget.accentColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: widget.accentColor),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              'No matches found. Try selecting from map.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          )
        else ...[
          for (final result in visible) _buildSuggestionTile(result),
          if (hiddenCount > 0)
            _buildFooterHint(
              '$hiddenCount more result${hiddenCount == 1 ? '' : 's'} — keep typing to narrow down',
            ),
        ],

        if (_landmarkSourceFailed && !_isSearching)
          _buildFooterHint(
            'Landmarks are unavailable right now — showing addresses only.',
            warning: true,
          ),
      ],
    );
  }

  Widget _buildFooterHint(String message, {bool warning = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          if (warning) ...[
            const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                color: warning ? const Color(0xFFB45309) : Colors.grey.shade500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(LocationSearchResult result) {
    final distance = _distanceLabel(result);

    return InkWell(
      onTap: () => _select(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(
              _iconFor(result.category),
              size: 18,
              color: _isLandmark(result.category)
                  ? widget.accentColor
                  : Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    _highlightedTitle(result.title, widget.controller.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      result.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 8),
              Text(
                distance,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bold the part of [title] the user actually typed, so specific matches are
  /// obvious at a glance.
  TextSpan _highlightedTitle(String title, String query) {
    const baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E293B),
    );
    const matchStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: Color(0xFF0F172A),
    );

    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toSet();
    if (tokens.isEmpty) return TextSpan(text: title, style: baseStyle);

    final lower = title.toLowerCase();
    final spans = <TextSpan>[];
    var index = 0;

    while (index < title.length) {
      var matched = '';
      for (final token in tokens) {
        if (lower.startsWith(token, index)) {
          matched = token;
          break;
        }
      }

      if (matched.isNotEmpty) {
        spans.add(TextSpan(
          text: title.substring(index, index + matched.length),
          style: matchStyle,
        ));
        index += matched.length;
      } else {
        final start = index;
        while (index < title.length &&
            !tokens.any((token) => lower.startsWith(token, index))) {
          index++;
        }
        spans.add(TextSpan(
          text: title.substring(start, index),
          style: baseStyle,
        ));
      }
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  String? _distanceLabel(LocationSearchResult result) {
    final lat = widget.proximityLat;
    final lng = widget.proximityLng;
    if (lat == null || lng == null) return null;
    final meters = GeocodingService.distanceMeters(
      lat,
      lng,
      result.latitude,
      result.longitude,
    );
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static bool _isLandmark(PlaceCategory category) => category.isPoi;

  static IconData _iconFor(PlaceCategory category) {
    return switch (category) {
      PlaceCategory.school => Icons.school_outlined,
      PlaceCategory.hospital => Icons.local_hospital_outlined,
      PlaceCategory.market => Icons.storefront_outlined,
      PlaceCategory.worship => Icons.church_outlined,
      PlaceCategory.government => Icons.account_balance_outlined,
      PlaceCategory.transit => Icons.directions_bus_outlined,
      PlaceCategory.shop => Icons.shopping_bag_outlined,
      PlaceCategory.food => Icons.restaurant_outlined,
      PlaceCategory.lodging => Icons.hotel_outlined,
      PlaceCategory.park => Icons.park_outlined,
      PlaceCategory.landmark => Icons.place_outlined,
      PlaceCategory.address => Icons.home_outlined,
      PlaceCategory.street => Icons.add_road_outlined,
      PlaceCategory.neighborhood ||
      PlaceCategory.locality ||
      PlaceCategory.place ||
      PlaceCategory.region =>
        Icons.location_city_outlined,
      PlaceCategory.unknown => Icons.location_on_outlined,
    };
  }

  Future<void> _openMapPicker() async {
    _focusNode.unfocus();
    _removeOverlay();

    if (widget.onSelectFromMap != null) {
      widget.onSelectFromMap!();
      return;
    }

    final result = await LocationMapPickerSheet.show(
      context,
      title: widget.hint,
      initialLat: widget.proximityLat,
      initialLng: widget.proximityLng,
      pinColor: widget.accentColor,
    );

    if (result != null) {
      widget.controller.text = result.fullAddress;
      widget.onLocationSelected?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: _onTextChanged,
        validator: widget.validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: widget.prefixIcon,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (widget.controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                  onPressed: () {
                    widget.controller.clear();
                    _onTextChanged('');
                  },
                ),
              IconButton(
                icon: Icon(Icons.map_outlined,
                    size: 20, color: widget.accentColor),
                tooltip: 'Select on map',
                onPressed: _openMapPicker,
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.accentColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFFDC2626), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
          ),
        ),
      ),
    );
  }
}
