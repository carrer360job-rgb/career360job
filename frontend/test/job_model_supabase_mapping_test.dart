import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/data/models/job_model.dart';

void main() {
  test('published Supabase job is open and uses stored listing details', () {
    final job = JobModel.fromMap({
      'id': 'job-1',
      'title': 'Store Manager',
      'company_name': 'Example Company',
      'district': 'Erode',
      'category': 'Retail',
      'description': 'Manage the store team.',
      'min_salary': 25000,
      'max_salary': 35000,
      'work_mode': 'On-site',
      'vacancies': 3,
      'contact_phone': '9000000000',
      'contact_email': 'hr@example.com',
      'status': 'PUBLISHED',
      'is_verified': true,
    });

    expect(job.isOpen, isTrue);
    expect(job.companyName, 'Example Company');
    expect(job.salaryText, '₹25000 - ₹35000');
    expect(job.vacanciesCount, 3);
    expect(job.phone, '9000000000');
    expect(job.email, 'hr@example.com');
    expect(job.isVerified, isTrue);
  });

  test('closed and expired listings cannot appear as open jobs', () {
    final listing = {
      'id': 'job-2',
      'title': 'Engineer',
      'status': 'PUBLISHED',
      'expires_at': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    };
    expect(JobModel.fromMap(listing).isOpen, isFalse);
    expect(JobModel.fromMap({...listing, 'status': 'CLOSED', 'expires_at': null}).isOpen, isFalse);
  });
}
