import 'package:flutter_test/flutter_test.dart';
import 'package:vetrijobs/core/services/supabase_service.dart';

void main() {
  test('all four saved onboarding steps populate the candidate profile', () {
    final profile = SupabaseService.candidateView(
      {
        'full_name': 'Asha Kumar',
        'district': 'Chennai',
        'profile_photo_url': 'https://example.com/photo.png',
        'personal_details': {
          'gender': 'Female',
          'maritalStatus': 'Single',
          'state': 'Tamil Nadu',
          'birthMonth': 'June',
          'birthYear': 2000,
        },
        'education': {
          'educationLevel': 'UG (Under Graduate)',
          'qualification': 'B.Sc Computer Science',
          'collegeOrSchool': 'Example College',
          'graduationYear': 2021,
        },
        'preferred_job_titles': ['Flutter Developer', 'QA Engineer'],
        'experience': {
          'hasExperience': true,
          'experienceYears': '2 Years',
          'experienceMonths': '3 Months',
          'lastCompany': 'Example Ltd',
          'lastJobTitle': 'Developer',
          'salary': '₹5 LPA',
          'noticePeriod': 'Immediate',
        },
      },
      {'email': 'asha@example.com', 'phone': '9876543210'},
    );

    expect(profile['fullName'], 'Asha Kumar');
    expect(profile['phone'], '9876543210');
    expect(profile['state'], 'Tamil Nadu');
    expect(profile['qualification'], 'B.Sc Computer Science');
    expect(profile['preferredJobTitles'], ['Flutter Developer', 'QA Engineer']);
    expect(profile['hasExperience'], true);
    expect(profile['lastCompany'], 'Example Ltd');
    expect(profile['profilePhotoUrl'], 'https://example.com/photo.png');
    expect(profile['age'], isA<int>());
  });
}
