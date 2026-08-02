import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trigo/app.dart';

void main() {
  testWidgets('TriGo app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TriGoApp(),
      ),
    );

    expect(find.text('TriGo'), findsAny);
  });
}
