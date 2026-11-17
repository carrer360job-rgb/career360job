import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/features/candidate/candidate_onboarding_wizard_screen.dart';
import 'package:vetrijobs/main.dart';

class _CandidateUser {
  final String uid = 'candidate-1';
  final bool emailVerified = true;
}

void main() {
  testWidgets('account rebuild keeps the saved onboarding stream and wizard', (
    tester,
  ) async {
    final profileUpdates = StreamController<Map<String, dynamic>?>.broadcast();
    final user = _CandidateUser();
    var subscriptions = 0;
    Stream<Map<String, dynamic>?> profileStream(String uid) {
      subscriptions++;
      return profileUpdates.stream;
    }

    Widget gate() => MaterialApp(
      home: CandidateSessionGate(
        user: user,
        onBackToLogin: () async {},
        onRoleChanged: (_) {},
        onSwitchRoleRequested: () {},
        onSignOutRequested: () {},
        onRetry: () async {},
        profileStreamFactory: profileStream,
      ),
    );

    await tester.pumpWidget(gate());
    profileUpdates.add({
      'onboarding_step': 1,
      'fullName': 'Test Candidate',
      'phone': '9876543210',
      'district': 'Chennai',
      'state': 'Tamil Nadu',
    });
    await tester.pump();
    expect(find.byType(CandidateOnboardingWizardScreen), findsOneWidget);
    expect(subscriptions, 1);

    await tester.pumpWidget(gate());
    await tester.pump();
    expect(find.byType(CandidateOnboardingWizardScreen), findsOneWidget);
    expect(subscriptions, 1);

    await profileUpdates.close();
  });
}
