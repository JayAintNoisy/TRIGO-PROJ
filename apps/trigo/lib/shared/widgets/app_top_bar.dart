import 'package:flutter/material.dart';
import 'app_back_button.dart';

/// Uniform top bar: blue header with a back button and centered title,
/// mirroring the auth screens' header row while staying as simple as a
/// plain [AppBar]. Pass [actions] to replace the invisible balancing
/// placeholder used to keep the title perfectly centered.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final String fallbackLocation;

  const AppTopBar({
    super.key,
    required this.title,
    this.actions,
    this.fallbackLocation = '/landing',
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2563EB),
      elevation: 0,
      leading: AppBackButton(
        fallbackLocation: fallbackLocation,
        backgroundColor: Colors.transparent,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      centerTitle: true,
      actions: actions ?? const [SizedBox(width: 48)],
    );
  }
}