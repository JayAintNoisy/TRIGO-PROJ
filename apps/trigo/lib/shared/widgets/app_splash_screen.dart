import 'package:flutter/material.dart';

import '../../core/constants/app_release.dart';

/// Boot splash shown while authentication and connectivity are resolved,
/// before any routed screen is rendered.
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({
    super.key,
    this.isOffline = false,
    this.isRetrying = false,
    this.onRetry,
  });

  final bool isOffline;
  final bool isRetrying;
  final VoidCallback? onRetry;

  /// Env-driven release identity: plain muted version text in production, or a
  /// small amber pill (e.g. `1.0.0-demo`) when a release channel label is set.
  Widget _buildReleaseInfo() {
    final text = AppReleaseInfo.display;
    if (AppReleaseInfo.isProduction) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.electric_rickshaw,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 12),
            const Text(
              'TriGo',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            _buildReleaseInfo(),
            const SizedBox(height: 32),
            if (isOffline && onRetry != null) ...[
              const Icon(Icons.wifi_off,
                  size: 28, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              const Text(
                'No internet connection',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Check your connection and try again',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ] else
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }
}
