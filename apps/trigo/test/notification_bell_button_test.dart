import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/notifications/presentation/widgets/notification_bell_button.dart';

void main() {
  Future<void> pumpBell(WidgetTester tester, {required int unread}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NotificationBellButton(unreadCount: unread, onTap: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hides the badge when everything is read', (tester) async {
    await pumpBell(tester, unread: 0);

    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the unread count on the badge', (tester) async {
    await pumpBell(tester, unread: 4);

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('caps the badge at 99+', (tester) async {
    await pumpBell(tester, unread: 140);

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NotificationBellButton(
              unreadCount: 2,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(NotificationBellButton));
    await tester.pump();

    expect(taps, 1);
  });
}
