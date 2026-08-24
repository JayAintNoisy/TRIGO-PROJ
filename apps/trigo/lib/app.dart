import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'shared/widgets/app_splash_screen.dart';

class TriGoApp extends ConsumerStatefulWidget {
  const TriGoApp({super.key});

  @override
  ConsumerState<TriGoApp> createState() => _TriGoAppState();
}

class _TriGoAppState extends ConsumerState<TriGoApp> {
  bool _isOnline = true;
  bool _isChecking = false;

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
    if (mounted) setState(() => _isChecking = false);
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
