import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_mode_switch.dart';
import 'customer_home_screen.dart';
import 'driver_home_screen.dart';

/// Renders the customer or driver home depending on the active mode,
/// preserving the state and map view of each screen using IndexedStack.
class HomeSwitcher extends ConsumerStatefulWidget {
  const HomeSwitcher({super.key});

  @override
  ConsumerState<HomeSwitcher> createState() => _HomeSwitcherState();
}

class _HomeSwitcherState extends ConsumerState<HomeSwitcher>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final activeMode = ref.watch(authProvider).activeMode;
    final isDriver = activeMode == AppUserMode.driver;

    return IndexedStack(
      index: isDriver ? 1 : 0,
      children: const [
        CustomerHomeScreen(),
        DriverHomeScreen(),
      ],
    );
  }
}
