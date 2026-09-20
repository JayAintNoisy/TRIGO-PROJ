import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/ride_booking/data/rides_repository.dart';
import 'shared/widgets/app_mode_switch.dart';
import 'shared/widgets/app_splash_screen.dart';

class TriGoApp extends ConsumerStatefulWidget {
  const TriGoApp({super.key});

  @override
  ConsumerState<TriGoApp> createState() => _TriGoAppState();
}

class _TriGoAppState extends ConsumerState<TriGoApp> {
  bool _isOnline = true;
  bool _isChecking = false;
  final _ridesRepository = RidesRepository();
  final _driversRepository = DriversRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runBootChecks();
    });
  }

  /// Connectivity and authentication are fully resolved before the router is
  /// mounted, so users never see a login screen mid-authentication.
  Future<void> _runBootChecks() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    var online = _isOnline;
    try {
      final results = await Connectivity().checkConnectivity();
      online = !results.contains(ConnectivityResult.none);
    } catch (_) {
      // A failed probe must never wedge the boot; treat as online and let
      // individual requests surface their own errors
      online = true;
    }
    if (!mounted) return;
    setState(() => _isOnline = online);
    if (!online) {
      setState(() => _isChecking = false);
      return;
    }

    await ref.read(authProvider.notifier).tryAutoLogin();
    if (!mounted) return;
    final resumePath = await _activeRidePath();
    // A driver returning to a live trip must be online again, or the
    // passenger stops seeing them. Done before navigating so the state is
    // correct by the time the tracking screen mounts.
    if (resumePath != null) {
      await _ensureDriverOnline();
      if (!mounted) return;
    }
    if (mounted) setState(() => _isChecking = false);
    if (resumePath != null && mounted) {
      // Defer to after the frame that mounts MaterialApp.router, so the
      // redirect runs against a live router rather than relying on go_router
      // buffering a location set while it is still unmounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) appRouter.go(resumePath);
      });
    }
  }

  /// The tracking path for a ride that is still in flight, or null when there
  /// is nothing to resume.
  ///
  /// Without this a restart mid-trip drops the user back on Home, losing the
  /// tracking screen entirely. Both roles are covered, but they use different
  /// status filters: a customer resumes any non-terminal ride of theirs,
  /// while a driver only resumes a ride they have actually accepted.
  Future<String?> _activeRidePath() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return null;
    try {
      final active = auth.activeMode == AppUserMode.driver
          ? await _ridesRepository.getDriverAssignedRide()
          : await _ridesRepository.getActiveRide();
      if (active is! Map) return null;
      final rideId = active['id']?.toString();
      if (rideId == null || rideId.isEmpty) return null;
      return '/ride/$rideId/tracking';
    } catch (_) {
      // A failed lookup must not block the boot; the user simply lands on
      // Home and can still resume from History.
      return null;
    }
  }

  /// Keeps a resumed driver discoverable to their passenger.
  ///
  /// A driver mid-trip must stay online, otherwise their GPS stops
  /// broadcasting and the passenger loses the live driver position. This is
  /// best-effort: a failure here must not prevent the ride from resuming.
  Future<void> _ensureDriverOnline() async {
    final auth = ref.read(authProvider);
    if (auth.activeMode != AppUserMode.driver) return;
    try {
      final profile = await _driversRepository.getMe();
      final isOnline = profile is Map && profile['isOnline'] == true;
      if (!isOnline) {
        await _driversRepository.toggleOnlineStatus(true);
      }
    } catch (_) {
      // Non-fatal; the driver can toggle online manually.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isBootstrapped || !_isOnline || _isChecking) {
      return MaterialApp(
        title: 'TriGo',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: AppSplashScreen(
          isOffline: !_isOnline,
          isRetrying: _isChecking,
          onRetry: _runBootChecks,
        ),
      );
    }

    return MaterialApp.router(
      title: 'TriGo',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
