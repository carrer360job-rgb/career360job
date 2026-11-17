import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/main.dart';
import 'package:vetrijobs/features/auth/role_selection_screen.dart';

void main() {
  testWidgets('Career360 App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(Career360App(authChanges: Stream.value(null)));
    await tester.pump();
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
  });

  testWidgets('startup loading uses one branded view without a spinner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SessionLoadingScreen()));
    expect(find.text('Loading...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
