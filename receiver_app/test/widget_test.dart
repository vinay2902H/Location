import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receiver_app/main.dart';
import 'package:receiver_app/models/location_data.dart';
import 'package:receiver_app/screens/receiver_screen.dart';
import 'package:receiver_app/screens/record_detail_screen.dart';
import 'package:receiver_app/services/socket_service.dart';
import 'package:receiver_app/widgets/username_record_card.dart';

void main() {
  setUp(() {
    SocketService().disconnect();
  });

  tearDown(() {
    SocketService().disconnect();
  });

  testWidgets('ReceiverApp smoke test: loads ReceiverScreen viewer directly', (WidgetTester tester) async {
    await tester.pumpWidget(const ReceiverApp());
    expect(find.text('WinzoWin'), findsOneWidget);
    expect(find.text('Live Location Receiver'), findsOneWidget);
    SocketService().disconnect();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ReceiverScreen displays live location receiver interface', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReceiverScreen(),
      ),
    );
    expect(find.textContaining('Live Location'), findsWidgets);
    expect(find.text('SENDERS SHARING LOCATION'), findsOneWidget);
    SocketService().disconnect();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('UsernameRecordCard displays username and navigates on arrow click',
      (WidgetTester tester) async {
    bool arrowClicked = false;
    final testRecord = LocationDataModel(
      id: 'test_id_123',
      userId: 'user_456',
      username: 'Player_Test',
      email: 'test@example.com',
      latitude: 17.385044,
      longitude: 78.486671,
      accuracy: 5.2,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UsernameRecordCard(
            record: testRecord,
            isLive: true,
            onTap: () {
              arrowClicked = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Player_Test'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    // Tap arrow button
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump();

    expect(arrowClicked, isTrue);
  });

  testWidgets('RecordDetailScreen displays sender details cleanly without logs or MongoDB attributes',
      (WidgetTester tester) async {
    final testRecord = LocationDataModel(
      id: 'test_record_999',
      userId: 'auth_usr_888',
      username: 'Player_Apex',
      email: 'apex@game.io',
      latitude: 12.9716,
      longitude: 77.5946,
      accuracy: 8.4,
      timestamp: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RecordDetailScreen(record: testRecord),
      ),
    );

    // Verify username, email, and title are shown
    expect(find.text('Player_Apex'), findsWidgets);
    expect(find.text('apex@game.io'), findsOneWidget);
    expect(find.text('Live Location Details'), findsOneWidget);

    // Verify GPS telemetry section
    expect(find.text('GPS TELEMETRY & COORDINATES'), findsOneWidget);
    expect(find.text('OPEN IN GOOGLE MAPS'), findsOneWidget);
    expect(find.text('LATITUDE'), findsOneWidget);
    expect(find.text('LONGITUDE'), findsOneWidget);

    // Verify logs and MongoDB attributes are NOT present
    expect(find.textContaining('ACTIVITY LOGS'), findsNothing);
    expect(find.text('MONGODB DATABASE ATTRIBUTES'), findsNothing);
    expect(find.text('DATABASE RECORD ID (_id)'), findsNothing);
    expect(find.text('RAW JSON DOCUMENT'), findsNothing);
  });
}
