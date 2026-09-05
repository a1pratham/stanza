import 'package:flutter_test/flutter_test.dart';
import 'package:stanza/main.dart';

void main() {
  testWidgets('Stanza app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const StanzaApp());

    expect(find.text('INDIA'), findsOneWidget);
  });
}