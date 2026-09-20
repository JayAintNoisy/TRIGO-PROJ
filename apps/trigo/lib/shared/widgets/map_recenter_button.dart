import 'package:flutter/material.dart';

/// Floating GPS recenter button used across map viewers.
class MapRecenterButton extends StatelessWidget {
  const MapRecenterButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.size = 42,
    this.iconSize = 22,
    this.color = const Color(0xFF2563EB),
    this.icon = Icons.my_location,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;
  final double iconSize;
  final Color color;

  /// Glyph shown when not loading. Defaults to the GPS crosshair; pass
  /// [Icons.zoom_out_map] for a "fit all points" action.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: iconSize - 2,
                    height: iconSize - 2,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    size: iconSize,
                    color: color,
                  ),
          ),
        ),
      ),
    );
  }
}
