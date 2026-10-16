import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trigo/core/constants/notification_types.dart';
import 'package:trigo/features/notifications/presentation/screens/notifications_screen.dart';

/// The list renders every kind with its own icon and only navigates where the
/// reader is allowed to go.
Future<void> _pumpScreen(
  WidgetTester tester,
  List<dynamic> notifications,
) async {
  SharedPreferences.setMockInitialValues({});
  // The screen's repository reads the API base URL from the dotenv map, which
  // main() normally loads at boot.
  dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');

  // Tall enough that every row is built: ListView.builder skips off-screen
  // rows, which would hide the icons under test.
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(
        path: '/notifications',
        builder: (context, state) => NotificationsScreen(
          notificationLoader: () async => notifications,
          markReadOverride: (_) async {},
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/ride/:id/tracking',
        builder: (context, state) => Scaffold(
          body: Text('TRACKING ${state.pathParameters['id']}${state.uri.query}'),
        ),
      ),
      GoRoute(
        path: '/ride/:id/rating',
        builder: (context, state) =>
            Scaffold(body: Text('RATING ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/ride/:id/details',
        builder: (context, state) =>
            Scaffold(body: Text('DETAILS ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/ride/:id/complete',
        builder: (context, state) =>
            Scaffold(body: Text('RECEIPT ${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

dynamic _notification({
  required String id,
  required String type,
  String title = 'Title',
  String body = 'Body',
  bool isRead = false,
  Map<String, dynamic>? metadata,
}) {
  return {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'isRead': isRead,
    'metadata': metadata,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

void main() {
  testWidgets('renders each kind with its own icon and the unread counts',
      (tester) async {
    await _pumpScreen(tester, [
      _notification(id: 'n1', type: NotificationTypes.rideRequest),
      _notification(id: 'n2', type: NotificationTypes.rideStarted),
      _notification(id: 'n3', type: NotificationTypes.rideCompleted),
      _notification(id: 'n4', type: NotificationTypes.paymentSent),
      _notification(id: 'n5', type: NotificationTypes.paymentReceived),
      _notification(id: 'n6', type: NotificationTypes.message),
      _notification(id: 'n7', type: 'announcement', isRead: true),
    ]);

    expect(find.text('All (7)'), findsOneWidget);
    expect(find.text('Unread (6)'), findsOneWidget);

    for (final type in [
      NotificationTypes.rideRequest,
      NotificationTypes.rideStarted,
      NotificationTypes.rideCompleted,
      NotificationTypes.paymentSent,
      NotificationTypes.paymentReceived,
      NotificationTypes.message,
    ]) {
      expect(find.byIcon(notificationVisualFor(type).icon), findsOneWidget);
    }
  });

  testWidgets('filtering to unread hides read rows', (tester) async {
    await _pumpScreen(tester, [
      _notification(
          id: 'n1', type: NotificationTypes.rideStarted, title: 'Started'),
      _notification(
        id: 'n2',
        type: 'announcement',
        title: 'Old news',
        isRead: true,
      ),
    ]);

    expect(find.text('Old news'), findsOneWidget);

    await tester.tap(find.textContaining('Unread'));
    await tester.pumpAndSettle();

    expect(find.text('Old news'), findsNothing);
    expect(find.text('Started'), findsOneWidget);
  });

  testWidgets('an unknown kind still renders with the fallback icon',
      (tester) async {
    await _pumpScreen(tester, [
      _notification(id: 'n1', type: 'brand_new_type', title: 'Something new'),
    ]);

    expect(find.text('Something new'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await _pumpScreen(tester, const []);

    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('a completed ride opens its receipt, not a fresh rating form',
      (tester) async {
    await _pumpScreen(tester, [
      _notification(
        id: 'n1',
        type: NotificationTypes.rideCompleted,
        title: 'Ride completed',
        metadata: const {'rideId': 'ride-9'},
      ),
    ]);

    await tester.tap(find.text('Ride completed'));
    await tester.pumpAndSettle();

    expect(find.text('DETAILS ride-9'), findsOneWidget);
  });

  testWidgets('a message alert opens the chat for that ride', (tester) async {
    await _pumpScreen(tester, [
      _notification(
        id: 'n1',
        type: NotificationTypes.message,
        title: 'New message from Juan',
        metadata: const {'rideId': 'ride-9', 'chat': true},
      ),
    ]);

    await tester.tap(find.text('New message from Juan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('TRACKING ride-9'), findsOneWidget);
    expect(find.textContaining('chat=1'), findsOneWidget);
  });

  testWidgets('a ride request sends the driver home instead of to the ride',
      (tester) async {
    await _pumpScreen(tester, [
      _notification(
        id: 'n1',
        type: NotificationTypes.rideRequest,
        title: 'New ride request',
        metadata: const {'rideId': 'ride-9'},
      ),
    ]);

    await tester.tap(find.text('New ride request'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('an announcement only marks itself read', (tester) async {
    await _pumpScreen(tester, [
      _notification(
        id: 'n1',
        type: 'announcement',
        title: 'Maintenance tonight',
        metadata: const {'rideId': 'ride-9'},
      ),
    ]);

    await tester.tap(find.text('Maintenance tonight'));
    await tester.pumpAndSettle();

    // Still on the list: nothing to open.
    expect(find.text('Maintenance tonight'), findsOneWidget);
    expect(find.text('Unread (0)'), findsOneWidget);
  });
}
