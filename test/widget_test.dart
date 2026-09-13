import 'package:flutter_test/flutter_test.dart';
import 'package:connect_call/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ConnectCallApp());
    expect(find.byType(ConnectCallApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
  });
}
