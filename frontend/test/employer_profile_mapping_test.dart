import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/data/models/employer_profile.dart';

void main() {
  test('saved company registration details populate the employer portal', () {
    final profile = EmployerProfile.fromMap({
      'company_name': 'Example Textiles',
      'logo_url': 'https://example.com/logo.png',
      'contact_name': 'Priya Kumar',
      'designation': 'HR Manager',
      'email': 'priya@example.com',
      'phone': '9876543210',
      'whatsapp_phone': '9123456780',
      'whatsapp_same_as_phone': false,
      'industry': 'Manufacturing',
      'company_size': '51–100',
      'description': 'Local textile manufacturer',
      'website': 'https://example.com',
      'address': '12 Market Road',
      'district': 'Erode',
      'state': 'Tamil Nadu',
      'postal_code': '638001',
      'is_verified': false,
    }, 'employer-1');

    expect(profile.companyName, 'Example Textiles');
    expect(profile.logoUrl, 'https://example.com/logo.png');
    expect(profile.contactName, 'Priya Kumar');
    expect(profile.designation, 'HR Manager');
    expect(profile.email, 'priya@example.com');
    expect(profile.phone, '9876543210');
    expect(profile.whatsappPhone, '9123456780');
    expect(profile.whatsappSameAsPhone, isFalse);
    expect(profile.industry, 'Manufacturing');
    expect(profile.companySize, '51–100');
    expect(profile.description, 'Local textile manufacturer');
    expect(profile.website, 'https://example.com');
    expect(profile.address, '12 Market Road');
    expect(profile.district, 'Erode');
    expect(profile.state, 'Tamil Nadu');
    expect(profile.postalCode, '638001');
    expect(profile.status, 'pending');
    expect(profile.isApproved, isFalse);
  });

  test('only the server-owned verification flag approves a company', () {
    final pending = EmployerProfile.fromMap({
      'status': 'approved',
      'is_verified': false,
    }, 'employer-1');
    final verified = EmployerProfile.fromMap({
      'is_verified': true,
    }, 'employer-1');

    expect(pending.isApproved, isFalse);
    expect(verified.isApproved, isTrue);
  });
}
