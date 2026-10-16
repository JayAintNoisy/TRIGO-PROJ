import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/branch_visibility.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'app_mode_switch.dart';

class AppScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({super.key, required this.navigationShell});

  void _onItemTapped(int index, BuildContext context, AppUserMode mode) {
    if (index == 1) {
      if (mode == AppUserMode.driver) {
        context.go('/driver/earnings');
      } else {
        context.go('/history');
      }
    } else {
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    // Branches stay alive, so their pages must be told they are visible again
    // in order to refresh (ride history and driver earnings both do).
    activeBranchNotifier.value = index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isDriver = authState.activeMode == AppUserMode.driver;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, -2),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => _onItemTapped(index, context, authState.activeMode),
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey.shade400,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.home_rounded),
                ),
                label: 'Home',
              ),
              if (isDriver)
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.account_balance_wallet_rounded),
                  ),
                  label: 'Earnings',
                )
              else
                const BottomNavigationBarItem(
                  icon: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Icon(Icons.history_rounded),
                  ),
                  label: 'History',
                ),
              const BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.person_rounded),
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
