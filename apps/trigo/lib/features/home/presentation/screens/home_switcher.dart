import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import 'customer_home_screen.dart';
import 'driver_home_screen.dart';

// Renders the customer or driver home depending on the active mode
class HomeSwitcher extends ConsumerWidget {
  const HomeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMode = ref.watch(authProvider).activeMode;
    return activeMode == AppUserMode.driver
        ? const DriverHomeScreen()
        : const CustomerHomeScreen();
  }
}
