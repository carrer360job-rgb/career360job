import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/main.dart';
import 'package:vetrijobs/features/splash/splash_screen.dart';

void main() {
  testWidgets('Career360 App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(Career360App(authChanges: Stream.value(null)));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
