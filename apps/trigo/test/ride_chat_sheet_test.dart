import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trigo/features/messaging/data/messaging_repository.dart';
import 'package:trigo/features/messaging/presentation/widgets/ride_chat_sheet.dart';

/// In-memory stand-in for the messaging API.
class _FakeMessagingRepository extends MessagingRepository {
  _FakeMessagingRepository({List<RideMessage>? initial, this.failSend = false})
      : messages = [...?initial];

  final List<RideMessage> messages;
  bool failSend;
  int markReadCalls = 0;

  @override
  Future<List<RideMessage>> getMessages(String rideId) async =>
      List<RideMessage>.from(messages);

  @override
  Future<RideMessage> sendMessage(String rideId, String body) async {
    if (failSend) throw Exception('network down');
    final message = RideMessage(
      id: 'sent-${messages.length + 1}',
      rideId: rideId,
      senderId: 'me',
      body: body,
      createdAt: DateTime.now(),
    );
    messages.add(message);
    return message;
  }

  @override
  Future<void> markRead(String rideId) async {
    markReadCalls++;
  }
}

const _me = 'me';
const _them = 'them';

RideMessage _message({
  required String id,
  required String senderId,
  required String body,
  DateTime? readAt,
}) {
  return RideMessage(
    id: id,
    rideId: 'ride-1',
    senderId: senderId,
    body: body,
    createdAt: DateTime(2026, 1, 1, 9, 30),
    readAt: readAt,
  );
}

Future<void> _pumpSheet(
  WidgetTester tester, {
  required _FakeMessagingRepository repository,
  Size size = const Size(411, 891),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RideChatSheet(
          rideId: 'ride-1',
          otherPartyName: 'Juan Dela Cruz',
          currentUserId: _me,
          otherPartyPhone: '09171112222',
          plateNumber: 'ABC-1234',
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    // The repository subclass still initialises the shared dio client, which
    // reads the API base URL from the dotenv map.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  testWidgets('shows the empty state and marks the thread read on open',
      (tester) async {
    final repository = _FakeMessagingRepository();

    await _pumpSheet(tester, repository: repository);

    expect(find.text('No messages yet'), findsOneWidget);
    expect(find.textContaining('Juan Dela Cruz'), findsWidgets);
    expect(repository.markReadCalls, 1);
  });

  testWidgets('renders both sides of the conversation', (tester) async {
    final repository = _FakeMessagingRepository(initial: [
      _message(id: 'm1', senderId: _them, body: 'I am at the gate'),
      _message(id: 'm2', senderId: _me, body: 'On my way', readAt: DateTime.now()),
    ]);

    await _pumpSheet(tester, repository: repository);

    expect(find.text('I am at the gate'), findsOneWidget);
    expect(find.text('On my way'), findsOneWidget);
    // Own read message shows the read marker.
    expect(find.textContaining('Read'), findsOneWidget);
  });

  testWidgets('sends a trimmed message and appends it', (tester) async {
    final repository = _FakeMessagingRepository(initial: [
      _message(id: 'm1', senderId: _them, body: 'Hello'),
    ]);

    await _pumpSheet(tester, repository: repository);
    await tester.enterText(find.byType(TextField), '  Waiting outside  ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repository.messages.last.body, 'Waiting outside');
    expect(find.text('Waiting outside'), findsOneWidget);
  });

  testWidgets('keeps the draft and explains a failed send', (tester) async {
    final repository = _FakeMessagingRepository(failSend: true);

    await _pumpSheet(tester, repository: repository);
    await tester.enterText(find.byType(TextField), 'Hello?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('network down'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Hello?',
      reason: 'the draft must survive a failed send',
    );
  });

  testWidgets('does not overflow on a small screen with large text',
      (tester) async {
    final repository = _FakeMessagingRepository(initial: [
      _message(id: 'm1', senderId: _them, body: 'A fairly long message body'),
      _message(id: 'm2', senderId: _me, body: 'Reply'),
    ]);

    await _pumpSheet(
      tester,
      repository: repository,
      size: const Size(320, 480),
      textScale: 2.0,
    );

    expect(tester.takeException(), isNull);
  });
}
