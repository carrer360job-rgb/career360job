import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/main.dart';
import 'package:vetrijobs/features/auth/role_selection_screen.dart';
import 'package:vetrijobs/core/services/app_auth_bridge.dart';
import 'package:vetrijobs/core/services/supabase_auth_service.dart';
import 'package:vetrijobs/features/employer/employer_login_screen.dart';

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

  testWidgets('verified recovery stays on password form instead of portal', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    SupabaseAuthService.recoveryVerified.value = true;
    SupabaseAuthService.recoveryRole = PasswordRecoveryRole.employer;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      SupabaseAuthService.recoveryVerified.value = false;
      SupabaseAuthService.recoveryRole = null;
    });
    await tester.pumpWidget(
      Career360App(
        authChanges: Stream.value(
          const AppAuthUser(uid: 'recovery-user', email: 'person@example.com'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Set New Password'), findsOneWidget);
    expect(find.text('EMPLOYER'), findsOneWidget);
    expect(find.text('Save New Password'), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('employer registration asks to confirm password, not phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(home: EmployerLoginScreen(onBack: () {})),
    );
    await tester.tap(find.text('Register Company').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Confirm Password *'), findsOneWidget);
    expect(find.text('Recruiter Contact Phone (Optional)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
