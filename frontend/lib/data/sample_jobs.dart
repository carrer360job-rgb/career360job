import 'models/job_model.dart';

/// Fictional, device-local listings used only to preview the candidate UI.
/// These are never written to Firestore and contain no real contact details.
class SampleJobs {
  SampleJobs._();

  static final List<JobModel> all = List.unmodifiable([
    _job(
      id: 'sample-assembly',
      title: 'Electronic Assembly Associate',
      company: 'Example Electronics',
      location: 'Erode district',
      salary: '₹15,000–₹18,000/month',
      category: 'Engineering & Manufacturing',
      daysAgo: 3,
      description: 'Join a small production team assembling electronic components and checking finished units. Training is provided for the equipment used on site.',
      requirements: ['Diploma or relevant degree', 'Attention to detail'],
      responsibilities: [
        'Assemble components',
        'Check quality and report defects',
      ],
    ),
    _job(
      id: 'sample-flutter',
      title: 'Junior Flutter Developer',
      company: 'Example Digital Studio',
      location: 'Coimbatore',
      salary: '₹20,000–₹28,000/month',
      category: 'IT & Software',
      daysAgo: 1,
      description: 'Help build and maintain Android app features with Flutter. Work with a mentor to turn product designs into reliable screens.',
      requirements: [
        'Basic Dart and Flutter knowledge',
        'Portfolio or project work',
      ],
      responsibilities: ['Build app screens', 'Fix bugs and review changes'],
    ),
    _job(
      id: 'sample-marketing',
      title: 'Digital Marketing Assistant',
      company: 'Example Media House',
      location: 'Chennai',
      salary: '₹18,000–₹24,000/month',
      category: 'Marketing',
      daysAgo: 2,
      description: 'Support campaign scheduling, content updates, and weekly performance reports for a local marketing team.',
      requirements: ['Clear written communication', 'Basic spreadsheet skills'],
      responsibilities: [
        'Schedule campaign content',
        'Prepare performance summaries',
      ],
    ),
    _job(
      id: 'sample-accounts',
      title: 'Accounts Assistant',
      company: 'Example Business Services',
      location: 'Coimbatore',
      salary: '₹16,000–₹22,000/month',
      category: 'Finance',
      daysAgo: 4,
      description: 'Organize invoices, reconcile records, and help the finance team prepare routine monthly reports.',
      requirements: [
        'Commerce background preferred',
        'Spreadsheet familiarity',
      ],
      responsibilities: ['Record invoices', 'Assist with reconciliations'],
    ),
    _job(
      id: 'sample-designer',
      title: 'Junior UI Designer',
      company: 'Example Product Lab',
      location: 'Chennai',
      salary: '₹22,000–₹30,000/month',
      category: 'Design',
      daysAgo: 5,
      description: 'Create clear mobile interface layouts and support usability reviews with the product team.',
      requirements: ['UI design portfolio', 'Figma basics'],
      responsibilities: [
        'Prepare screen layouts',
        'Update designs from feedback',
      ],
    ),
    _job(
      id: 'sample-healthcare',
      title: 'Clinic Front Desk Assistant',
      company: 'Example Community Clinic',
      location: 'Erode district',
      salary: '₹14,000–₹18,000/month',
      category: 'Healthcare',
      daysAgo: 2,
      description: 'Welcome visitors, coordinate appointments, and keep the reception desk organized during clinic hours.',
      requirements: [
        'Comfortable speaking with patients',
        'Basic computer use',
      ],
      responsibilities: ['Manage appointments', 'Maintain reception records'],
    ),
    _job(
      id: 'sample-tutor',
      title: 'After-school Tutor',
      company: 'Example Learning Centre',
      location: 'Coimbatore',
      salary: '₹12,000–₹18,000/month',
      category: 'Education',
      daysAgo: 6,
      description: 'Guide small groups of school students through homework and foundational maths and English lessons.',
      requirements: ['Relevant subject knowledge', 'Patient teaching style'],
      responsibilities: ['Lead study sessions', 'Track student progress'],
    ),
    _job(
      id: 'sample-office',
      title: 'Office Coordinator',
      company: 'Example Operations Co.',
      location: 'Chennai',
      salary: '₹17,000–₹23,000/month',
      category: 'Operations & Admin',
      daysAgo: 3,
      description: 'Coordinate day-to-day office requests, maintain records, and help colleagues prepare schedules and documents.',
      requirements: [
        'Organized and dependable',
        'Email and spreadsheet basics',
      ],
      responsibilities: ['Coordinate schedules', 'Keep records up to date'],
    ),
    _job(
      id: 'sample-technician',
      title: 'Maintenance Technician Trainee',
      company: 'Example Industrial Works',
      location: 'Erode district',
      salary: '₹16,000–₹20,000/month',
      category: 'Engineering & Manufacturing',
      daysAgo: 7,
      description: 'Assist experienced technicians with routine equipment checks and basic maintenance in a workshop.',
      requirements: ['ITI or diploma preferred', 'Willingness to learn safely'],
      responsibilities: ['Help inspect equipment', 'Record maintenance work'],
    ),
    _job(
      id: 'sample-support',
      title: 'Customer Support Associate',
      company: 'Example Service Desk',
      location: 'Remote',
      salary: '₹18,000–₹25,000/month',
      category: 'Operations & Admin',
      daysAgo: 1,
      workMode: 'Remote',
      description: 'Respond to customer questions through chat and email and document recurring issues for the support team.',
      requirements: ['Clear written communication', 'Reliable internet access'],
      responsibilities: ['Answer support requests', 'Maintain help records'],
    ),
  ]);

  static bool containsId(String id) => all.any((job) => job.id == id);

  static List<JobModel> matching({
    String? category,
    String? location,
    String? query,
  }) {
    final search = query?.trim().toLowerCase() ?? '';
    return all.where((job) {
      if (category != null &&
          category != 'All' &&
          category != 'All Categories' &&
          job.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      if (location != null &&
          location != 'All Locations' &&
          !job.locationCity.toLowerCase().contains(location.toLowerCase()) &&
          !job.workMode.toLowerCase().contains(location.toLowerCase())) {
        return false;
      }
      if (search.isEmpty) return true;
      return [
        job.title,
        job.companyName,
        job.locationCity,
        job.category,
        job.description,
      ].any((value) => value.toLowerCase().contains(search));
    }).toList();
  }

  static JobModel _job({
    required String id,
    required String title,
    required String company,
    required String location,
    required String salary,
    required String category,
    required int daysAgo,
    required String description,
    required List<String> requirements,
    required List<String> responsibilities,
    String workMode = 'On-site',
  }) {
    return JobModel(
      id: id,
      title: title,
      companyName: company,
      locationCity: location,
      salaryText: salary,
      category: category,
      workMode: workMode,
      vacanciesCount: 1,
      description: description,
      phone: '+91 94433 22110',
      whatsappNumber: '+91 94433 22110',
      email: 'careers@career360jobs.in',
      contactName: 'Recruitment HR Desk',
      isVerified: false,
      postedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      isDemo: true,
      requirements: requirements,
      responsibilities: responsibilities,
    );
  }
}
