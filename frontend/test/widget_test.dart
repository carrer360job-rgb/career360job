import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/main.dart';

void main() {
  testWidgets('Career360 App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const Career360App());
    expect(find.text('Career360'), findsNothing); // Starts on splash screen
  });
}
