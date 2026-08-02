import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

class TriGoApp extends ConsumerStatefulWidget {
  const TriGoApp({super.key});

  @override
  ConsumerState<TriGoApp> createState() => _TriGoAppState();
}

class _TriGoAppState extends ConsumerState<TriGoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TriGo',
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
