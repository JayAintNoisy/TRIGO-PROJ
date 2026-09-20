import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/services/geocoding_service.dart';
import '../../../../shared/widgets/location_map_picker_sheet.dart';

/// An address input with 300ms debounced geocoding search suggestions and
/// "Select from Map" integration.
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
  final ValueChanged<LocationSearchResult>? onLocationSelected;
  final VoidCallback? onSelectFromMap;

  @override
  State<AddressSearchInput> createState() => _AddressSearchInputState();
}

class _AddressSearchInputState extends State<AddressSearchInput> {
  final _geocodingService = GeocodingService();
  final _layerLink = LayerLink();
  final _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;
  List<LocationSearchResult> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      _showOverlay();

      final results = await _geocodingService.search(
        text,
        proximityLat: widget.proximityLat,
        proximityLng: widget.proximityLng,
      );

      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
        _updateOverlay();
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _updateOverlay();
      return;
    }

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
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
              constraints: const BoxConstraints(maxHeight: 240),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
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
        else
          ..._suggestions.map((result) {
            return InkWell(
              onTap: () {
                widget.controller.text = result.fullAddress;
                widget.onLocationSelected?.call(result);
                _removeOverlay();
                _focusNode.unfocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (result.subtitle.isNotEmpty)
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
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
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
