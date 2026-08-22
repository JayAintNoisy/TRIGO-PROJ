import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/widgets/app_mode_switch.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/passenger_register_screen.dart';
import '../../features/auth/presentation/screens/driver_register_screen.dart';
import '../../features/home/presentation/screens/home_switcher.dart';
import '../../features/ride_booking/presentation/screens/booking_screen.dart';
import '../../features/ride_booking/presentation/screens/ride_tracking_screen.dart';
import '../../features/ride_booking/presentation/screens/ride_complete_screen.dart';
import '../../features/ride_booking/presentation/screens/pick_driver_screen.dart';
import '../../features/ride_booking/presentation/screens/rating_screen.dart';
import '../../features/driver_application/presentation/screens/driver_application_screen.dart';
import '../../features/driver_application/presentation/screens/driver_status_screen.dart';
import '../../features/earnings/presentation/screens/earnings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/support/presentation/screens/help_support_screen.dart';
import '../../shared/widgets/app_scaffold.dart';

final authRedirectNotifier = ValueNotifier<AuthState?>(null);

final _protectedRoutes = [
  '/home', '/history', '/profile', '/book', '/pick-driver',
  '/driver/earnings', '/driver/apply', '/driver/status',
  '/notifications', '/settings', '/support',
];

// Main pages an unverified driver must not reach until their application is
// approved; verification screens and account pages stay accessible.
final _driverBlockedRoutes = [
  '/home', '/history', '/driver/earnings', '/book', '/pick-driver', '/ride/',
];

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

// A driver whose application is not yet approved (pending/reviewing/rejected/
// suspended) or who registered as a driver but never submitted details.
bool _isUnverifiedDriver(AuthState auth) {
  final status = auth.driverStatus;
  if (status == 'approved') return false;
  if (status != null) return true;
  return auth.activeMode == AppUserMode.driver;
}

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/landing',
  refreshListenable: authRedirectNotifier,
  redirect: (context, state) async {
    final auth = authRedirectNotifier.value;
    final isAuth = auth?.isAuthenticated ?? false;
    final location = state.matchedLocation;
    final isOnProtected =
        _protectedRoutes.any((r) => location.startsWith(r));

    if (isOnProtected && !isAuth) return '/login';

    // Unverified drivers are kept on the verification flow instead of the
    // main ride/driver pages (e.g. after login or app restart).
    if (isAuth && _isUnverifiedDriver(auth!)) {
      final isOnBlocked =
          _driverBlockedRoutes.any((r) => location.startsWith(r));
      if (isOnBlocked) {
        return auth.driverStatus == null ? '/driver/apply' : '/driver/status';
      }
    }

    final authPages = ['/landing', '/login', '/register'];
    final isOnAuthPage = authPages.any((p) => location.startsWith(p));
    if (isAuth && isOnAuthPage) return '/home';

    // First-run users see the showcase; everyone else lands straight on Login
    if (!isAuth && location.startsWith('/landing')) {
      if (await hasOnboarded()) return '/login';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/landing',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register/passenger',
      builder: (context, state) => const PassengerRegisterScreen(),
    ),
    GoRoute(
      path: '/register/driver',
      builder: (context, state) => const DriverRegisterScreen(),
    ),
    GoRoute(
      path: '/book',
      builder: (context, state) => const BookingScreen(),
    ),
    GoRoute(
      path: '/pick-driver',
      name: 'pick-driver',
      builder: (context, state) => PickDriverScreen(
        rideId: state.uri.queryParameters['rideId'],
        pickup: state.uri.queryParameters['pickup'],
        dropoff: state.uri.queryParameters['dropoff'],
      ),
    ),
    GoRoute(
      path: '/ride/:id/tracking',
      builder: (context, state) => RideTrackingScreen(
        rideId: state.pathParameters['id'],
      ),
    ),
    GoRoute(
      path: '/ride/:id/complete',
      builder: (context, state) => RideCompleteScreen(
        rideId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/ride/:id/rating',
      builder: (context, state) => RatingScreen(
        rideId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/driver/apply',
      builder: (context, state) => const DriverApplicationScreen(),
    ),
    GoRoute(
      path: '/driver/status',
      builder: (context, state) => const DriverStatusScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/support',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeSwitcher(),
        ),
        GoRoute(
          path: '/history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: '/driver/earnings',
          builder: (context, state) => const EarningsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
