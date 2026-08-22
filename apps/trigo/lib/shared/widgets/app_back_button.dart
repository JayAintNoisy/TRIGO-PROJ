import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppBackButton extends StatelessWidget {
  final Color iconColor;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;
  final String fallbackLocation;

  const AppBackButton({
    super.key,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.boxShadow,
    this.fallbackLocation = '/landing',
  });

  @override
  Widget build(BuildContext context) {
    if (!context.canPop()) {
      return const SizedBox(width: 48, height: 48);
    }

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              backgroundColor ?? Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          boxShadow: boxShadow,
        ),
        child: Icon(Icons.arrow_back, color: iconColor, size: 20),
      ),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
      },
    );
  }
}
