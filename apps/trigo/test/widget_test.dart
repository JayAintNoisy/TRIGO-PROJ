import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trigo/app.dart';

void main() {
  testWidgets('TriGo app smoke test', (WidgetTester tester) async {
    // The network layer reads .env at construction; provide test values
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api\n');
    // The router redirect reads persisted state during navigation
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: TriGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Fresh installs land on the onboarding showcase
    expect(find.text('Book in Seconds'), findsOneWidget);
  });
}
