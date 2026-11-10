class JobModel {
  final String id;
  final String title;
  final String? titleTamil;
  final String companyName;
  final String locationCity;
  final String salaryText;
  final String category;
  final String workMode; // On-Site, Remote, Hybrid
  final int vacanciesCount;
  final String description;
  final bool isVerified;
  final DateTime postedAt;

  JobModel({
    required this.id,
    required this.title,
    this.titleTamil,
    required this.companyName,
    required this.locationCity,
    required this.salaryText,
    required this.category,
    required this.workMode,
    required this.vacanciesCount,
    required this.description,
    this.isVerified = true,
    required this.postedAt,
  });
}
