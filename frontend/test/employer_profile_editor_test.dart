import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/data/models/employer_profile.dart';
import 'package:vetrijobs/features/employer/employer_registration_screen.dart';

void main() {
  testWidgets('company profile editor prefills all three steps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = EmployerProfile.fromMap({
      'company_name': 'Example Textiles',
      'industry': 'Manufacturing & Production',
      'company_size': '51â€“100',
      'description': 'Local textile manufacturer',
      'website': 'https://example.com',
      'contact_name': 'Priya Kumar',
      'designation': 'HR / Recruiter',
      'email': 'priya@example.com',
      'phone': '9876543210',
      'whatsapp_phone': '9123456780',
      'whatsapp_same_as_phone': false,
      'address': '12 Market Road',
      'district': 'Erode',
      'state': 'Tamil Nadu',
      'postal_code': '638001',
    }, 'employer-1');

    await tester.pumpWidget(
      MaterialApp(
        home: EmployerRegistrationScreen(
          initialProfile: profile,
          onSignOut: () {},
          onSubmissionStarted: () {},
          onSubmissionFailed: () {},
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('Recruiter Info'), findsOneWidget);
    expect(find.byTooltip('Back to company profile'), findsOneWidget);
    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('HR / Recruiter'), findsOneWidget);
    expect(find.text('9123456780'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Continue')));
    await tester.pumpAndSettle();
    expect(find.text('Company Details'), findsOneWidget);
    expect(find.text('Example Textiles'), findsOneWidget);
    expect(find.text('Manufacturing & Production'), findsOneWidget);
    expect(find.text('51â€“100'), findsOneWidget);
    expect(find.text('Local textile manufacturer'), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Continue')));
    await tester.pumpAndSettle();
    expect(find.text('Location Details'), findsOneWidget);
    expect(find.text('Tamil Nadu'), findsOneWidget);
    expect(find.text('Erode'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}
