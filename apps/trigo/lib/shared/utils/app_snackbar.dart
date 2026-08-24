import 'dart:async';
import 'package:flutter/material.dart';

enum AppSnackBarType {
  error,
  warning,
  success,
  info,
}

/// Custom top-anchored banner snackbar with distinct message types,
/// standard title and description, and dismiss capability.
class AppSnackBar {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String description,
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    _dismissCurrent();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopSnackBarWidget(
        title: title,
        description: description,
        type: type,
        onDismiss: () {
          _dismissCurrent();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      _dismissCurrent();
    });
  }

  static void error(
    BuildContext context, {
    String title = 'Out of Service Area',
    required String description,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      description: description,
      type: AppSnackBarType.error,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context, {
    String title = 'Notice',
    required String description,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      description: description,
      type: AppSnackBarType.warning,
      duration: duration,
    );
  }

  static void success(
    BuildContext context, {
    String title = 'Success',
    required String description,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      description: description,
      type: AppSnackBarType.success,
      duration: duration,
    );
  }

  static void info(
    BuildContext context, {
    String title = 'Information',
    required String description,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      title: title,
      description: description,
      type: AppSnackBarType.info,
      duration: duration,
    );
  }

  static void _dismissCurrent() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null && _currentEntry!.mounted) {
      _currentEntry!.remove();
    }
    _currentEntry = null;
  }
}

/// Convenience standalone function
void showAppSnackBar(
  BuildContext context, {
  required String message,
  String? title,
  bool isError = false,
  AppSnackBarType? type,
  Duration duration = const Duration(seconds: 4),
}) {
  final resolvedType = type ?? (isError ? AppSnackBarType.error : AppSnackBarType.success);
  final resolvedTitle = title ??
      (resolvedType == AppSnackBarType.error
          ? 'Error'
          : (resolvedType == AppSnackBarType.warning
              ? 'Notice'
              : (resolvedType == AppSnackBarType.success ? 'Success' : 'Information')));

  AppSnackBar.show(
    context,
    title: resolvedTitle,
    description: message,
    type: resolvedType,
    duration: duration,
  );
}

class _TopSnackBarWidget extends StatefulWidget {
  const _TopSnackBarWidget({
    required this.title,
    required this.description,
    required this.type,
    required this.onDismiss,
  });

  final String title;
  final String description;
  final AppSnackBarType type;
  final VoidCallback onDismiss;

  @override
  State<_TopSnackBarWidget> createState() => _TopSnackBarWidgetState();
}

class _TopSnackBarWidgetState extends State<_TopSnackBarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();
  }

  Future<void> _handleDismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color, Color, Color, Color, IconData) _typeStyle() {
    switch (widget.type) {
      case AppSnackBarType.error:
        return (
          const Color(0xFFDC2626), // Icon Color
          const Color(0xFFFEE2E2), // Icon Bg
          const Color(0xFFFCA5A5), // Border
          const Color(0xFF991B1B), // Title Color
          Icons.error_outline_rounded,
        );
      case AppSnackBarType.warning:
        return (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          const Color(0xFFFCD34D),
          const Color(0xFF92400E),
          Icons.warning_amber_rounded,
        );
      case AppSnackBarType.success:
        return (
          const Color(0xFF10B981),
          const Color(0xFFD1FAE5),
          const Color(0xFF6EE7B7),
          const Color(0xFF065F46),
          Icons.check_circle_outline_rounded,
        );
      case AppSnackBarType.info:
        return (
          const Color(0xFF2563EB),
          const Color(0xFFDBEAFE),
          const Color(0xFF93C5FD),
          const Color(0xFF1E40AF),
          Icons.info_outline_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final (iconColor, iconBg, borderColor, titleColor, iconData) = _typeStyle();

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Dismissible(
              key: const ValueKey('top_app_snackbar_dismissible'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(iconData, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _handleDismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
