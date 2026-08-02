import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/landing_screen.dart';
import '../../features/home/presentation/screens/customer_home_screen.dart';
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

final authRedirectNotifier = ValueNotifier<bool>(false);

final _protectedRoutes = [
  '/home', '/history', '/profile', '/book', '/pick-driver',
  '/driver/earnings', '/driver/apply', '/driver/status',
  '/notifications', '/settings', '/support',
];

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/landing',
  refreshListenable: authRedirectNotifier,
  redirect: (context, state) {
    final isAuth = authRedirectNotifier.value;
    final isOnProtected =
        _protectedRoutes.any((r) => state.matchedLocation.startsWith(r));

    if (isOnProtected && !isAuth) return '/landing';
    if (state.matchedLocation == '/landing' && isAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/landing',
      builder: (context, state) => const LandingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/book',
      builder: (context, state) => const BookingScreen(),
    ),
    GoRoute(
      path: '/pick-driver',
      name: 'pick-driver',
      builder: (context, state) => const PickDriverScreen(),
    ),
    GoRoute(
      path: '/ride/:id/tracking',
      builder: (context, state) => RideTrackingScreen(
        rideId: state.pathParameters['id'] ?? 'ride-uuid-001',
      ),
    ),
    GoRoute(
      path: '/ride/:id/complete',
      builder: (context, state) => RideCompleteScreen(
        rideId: state.pathParameters['id'] ?? 'ride-uuid-001',
      ),
    ),
    GoRoute(
      path: '/ride/:id/rating',
      builder: (context, state) => const RatingScreen(),
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
          builder: (context, state) => const CustomerHomeScreen(),
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
