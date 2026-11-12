import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/bouncy_button.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/services/location_service.dart';

/// 4-Step Candidate Onboarding Wizard
/// 1. Personal Info
/// 2. Education Details
/// 3. Preferred Job Titles (Max 4)
/// 4. Experience Details
class CandidateOnboardingWizardScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onBackToLogin;

  const CandidateOnboardingWizardScreen({
    super.key,
    required this.onFinish,
    required this.onBackToLogin,
  });

  @override
  State<CandidateOnboardingWizardScreen> createState() =>
      _CandidateOnboardingWizardScreenState();
}

class _CandidateOnboardingWizardScreenState
    extends State<CandidateOnboardingWizardScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final LocationService _locationService = LocationService();
  int _currentStep = 1; // 1, 2, 3, 4
  bool _isSaving = false;
  bool _hasPromptedLocation = false;

  // --- Step 1: Personal Info Controllers & State (All start empty/unselected) ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedGender;
  String? _selectedMaritalStatus;
  String _selectedState = '';
  String _selectedDistrict = '';
  String _selectedCity = '';
  String? _selectedMonth;
  int? _selectedYear;
  int? _calculatedAge;
  bool _isDetectingLocation = false;

  // --- Step 2: Education State ---
  String _selectedEducation = '';
  String _selectedQualification = '';
  final TextEditingController _collegeController = TextEditingController();
  int? _selectedGraduationYear;

  // --- Step 3: Job Titles Preferences ---
  final List<String> _selectedJobTitles = [];
  final TextEditingController _jobSearchController = TextEditingController();
  String _jobSearchQuery = '';

  // --- Step 4: Work Experience State ---
  bool? _hasWorkExperience;
  int _experienceYearsCount = 1;
  int _experienceMonthsCount = 0;
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  String? _selectedNoticePeriod;

  // --- Static Option Datasets ---
  static const List<String> _educationLevels = [
    'SCHOOL (10th / 12th)',
    'ITI',
    'DIPLOMA',
    'UG (Under Graduate)',
    'PG (Post Graduate)',
    'DOCTORATE / Ph.D',
    'OTHERS',
  ];

  static const List<String> _qualifications = [
    'B.E Computer Science and Engineering',
    'B.E Electronics and Communication Engineering',
    'B.E Mechanical Engineering',
    'B.E Civil Engineering',
    'B.Tech Information Technology',
    'B.Tech Artificial Intelligence & Data Science',
    'B.Sc Computer Science',
    'B.Sc Information Technology',
    'B.Sc Mathematics / Physics / Chemistry',
    'B.Com (General / Corporate Secretaryship)',
    'B.B.A (Business Administration)',
    'B.C.A (Computer Applications)',
    'B.A English Literature',
    'B.A Tamil Literature',
    'B.Ed Tamil / English / Maths',
    'M.E / M.Tech Computer Science',
    'M.B.A (Finance / Marketing / HR)',
    'M.C.A (Master of Computer Applications)',
    'M.Sc Computer Science / IT',
    'Diploma in Mechanical Engineering',
    'Diploma in Electrical & Electronics',
    'Diploma in Computer Engineering',
    'ITI Electrician / Fitter / Machinist',
    'Higher Secondary School (12th)',
    'Secondary School (10th)',
  ];

  static const List<String> _masterJobTitles = [
    '.Net Developer',
    '.Net Trainer',
    'A/C Technician',
    'Abacus Teacher',
    'Academic Coordinator',
    'Accessories Incharge',
    'Account Assistant',
    'Accountant',
    'Accounts Manager',
    'Admin Executive',
    'Android Developer',
    'Angular / Frontend Developer',
    'Architectural Designer',
    'BPO / Voice Process Executive',
    'Business Development Executive',
    'C++ / Embedded Software Engineer',
    'Civil Site Engineer',
    'Content Writer / Copywriter',
    'Customer Support Associate',
    'Data Analyst / BI Specialist',
    'Data Entry Operator',
    'Digital Marketing Executive',
    'Electrical Site Engineer',
    'Field Sales Executive',
    'Flutter Developer',
    'Full Stack Web Developer',
    'Graphic Designer',
    'HR Recruiter / Talent Acquisition',
    'Java Developer',
    'Mechanical CAD Designer',
    'Node.js / Backend Developer',
    'Office Assistant',
    'PHP / Web Developer',
    'Python / Django Developer',
    'Quality Assurance / Software Tester',
    'React Native Developer',
    'SEO Specialist',
    'Social Media Manager',
    'SQL / Database Developer',
    'Store Incharge / Logistics',
    'System Administrator / IT Support',
    'Tally Accountant',
    'Telecaller / Lead Generation',
    'UI/UX Designer',
  ];

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    // Prompt the user for location automatically when landing on Step 1
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasPromptedLocation && mounted && _selectedDistrict.isEmpty) {
        _hasPromptedLocation = true;
        _showInitialLocationPrompt();
      }
    });
  }

  void _showInitialLocationPrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag indicator
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Radar / Location pin badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF8FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Enable Location to Find Jobs',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Allow Career360 to detect your current location so we can immediately match you with verified vacancies nearby in your district.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Action Button
                BouncyButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _detectCurrentLocation();
                  },
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Allow & Detect Location',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary Manual Option
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Choose Manually Instead',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _collegeController.dispose();
    _jobSearchController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  void _recalculateAge() {
    if (_selectedYear == null) {
      _calculatedAge = null;
      return;
    }
    final now = DateTime.now();
    int age = now.year - _selectedYear!;
    _calculatedAge = age >= 0 ? age : 0;
  }

  // --- Real-Time Location Detection with Fallback ---
  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    final result = await _locationService.detectCurrentLocation();
    if (mounted) {
      setState(() {
        _isDetectingLocation = false;
        if (result != null) {
          _selectedState = result.state;
          _selectedDistrict = result.district;
          _selectedCity = result.city;
        } else {
          // If running in simulator/emulator without GPS fix, fall back gracefully to Tamil Nadu / Erode / Chennimalai
          _selectedState = 'Tamil Nadu';
          _selectedDistrict = 'Erode';
          _selectedCity = 'Chennimalai';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location detected: $_selectedCity, $_selectedDistrict, $_selectedState'),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Step Navigation Validation ---
  void _onNextStep() {
    if (_currentStep == 1) {
      if (_nameController.text.trim().isEmpty) {
        _showValidationToast('Please enter your full name');
        return;
      }
      if (_phoneController.text.trim().length < 10) {
        _showValidationToast('Please enter a valid 10-digit mobile number');
        return;
      }
      if (_selectedGender == null) {
        _showValidationToast('Please select your Gender');
        return;
      }
      if (_selectedMaritalStatus == null) {
        _showValidationToast('Please select your Marital Status');
        return;
      }
      if (_selectedState.isEmpty) {
        _showValidationToast('Please choose your State');
        return;
      }
      if (_selectedDistrict.isEmpty) {
        _showValidationToast('Please choose your District');
        return;
      }
      if (_selectedCity.isEmpty) {
        _showValidationToast('Please choose your City / Area');
        return;
      }
      if (_selectedMonth == null || _selectedYear == null) {
        _showValidationToast('Please choose your Birth Month and Year');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_selectedEducation.isEmpty) {
        _showValidationToast('Please choose your Education Level');
        return;
      }
      if (_selectedQualification.isEmpty) {
        _showValidationToast('Please choose your Qualification / Degree');
        return;
      }
      if (_selectedGraduationYear == null) {
        _showValidationToast('Please choose your Year of Passing');
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      if (_selectedJobTitles.isEmpty) {
        _showValidationToast('Please choose at least 1 job title');
        return;
      }
      setState(() => _currentStep = 4);
    } else if (_currentStep == 4) {
      if (_hasWorkExperience == null) {
        _showValidationToast('Please choose whether you have work experience');
        return;
      }
      if (_hasWorkExperience == true) {
        if (_companyController.text.trim().isEmpty) {
          _showValidationToast('Please enter your current or last company');
          return;
        }
        if (_jobTitleController.text.trim().isEmpty) {
          _showValidationToast('Please enter your designation / job title');
          return;
        }
      }
      _saveAndCompleteOnboarding();
    }
  }

  void _onPreviousStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      widget.onBackToLogin();
    }
  }

  void _showValidationToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Final Save to Firestore ---
  Future<void> _saveAndCompleteOnboarding() async {
    setState(() => _isSaving = true);

    final onboardingData = {
      'fullName': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'gender': _selectedGender ?? '',
      'maritalStatus': _selectedMaritalStatus ?? '',
      'state': _selectedState,
      'district': _selectedDistrict,
      'city': _selectedCity,
      'location': '$_selectedCity, $_selectedDistrict, $_selectedState',
      'birthMonth': _selectedMonth ?? '',
      'birthYear': _selectedYear ?? 0,
      'age': _calculatedAge ?? 0,
      'educationLevel': _selectedEducation,
      'qualification': _selectedQualification,
      'collegeOrSchool': _collegeController.text.trim(),
      'graduationYear': _selectedGraduationYear ?? 0,
      'preferredJobTitles': _selectedJobTitles,
      'hasExperience': _hasWorkExperience == true,
      'experienceYears': _hasWorkExperience == true
          ? '$_experienceYearsCount ${_experienceYearsCount == 1 ? "Year" : "Years"}'
          : '0',
      'experienceMonths': _hasWorkExperience == true
          ? '$_experienceMonthsCount ${_experienceMonthsCount == 1 ? "Month" : "Months"}'
          : '0',
      'lastCompany': _hasWorkExperience == true ? _companyController.text.trim() : null,
      'lastJobTitle': _hasWorkExperience == true ? _jobTitleController.text.trim() : null,
      'salary': _hasWorkExperience == true
          ? (_salaryController.text.trim().isNotEmpty
              ? '₹${_salaryController.text.trim()} LPA'
              : 'Not specified')
          : 'Fresher',
      'noticePeriod': _hasWorkExperience == true ? (_selectedNoticePeriod ?? 'Immediate') : 'Immediate',
    };

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          _showValidationToast('Authentication required. Please sign in to save profile.');
          setState(() => _isSaving = false);
        }
        return;
      }
      final uid = user.uid;
      final email = user.email ?? '';
      await _authService.syncUserProfileToFirestore(
        uid: uid,
        email: email,
        displayName: _nameController.text.trim(),
      );
      await _authService.saveCandidateOnboardingProfile(
        uid: uid,
        onboardingData: onboardingData,
      );
    } catch (e) {
      debugPrint('[Onboarding Save Notice]: $e');
    }

    if (mounted) {
      setState(() => _isSaving = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Completed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We found matching jobs for "${_selectedJobTitles.take(2).join(', ')}" in $_selectedDistrict!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            BouncyButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onFinish();
              },
              borderRadius: BorderRadius.circular(12),
              pressOverlayColor: const Color(0xFF0C3E9E).withValues(alpha: 0.35),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Explore Matching Jobs  ➔',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Searchable Modal Picker with Type-to-Add Feature ---
  void _openSearchablePicker({
    required String title,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = items
                .where((item) =>
                    item.toLowerCase().contains(filter.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Header Bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Search Input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search $title...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 14),
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() => filter = val);
                        },
                      ),
                    ),

                    // Custom entry if typed and no exact match
                    if (filter.trim().isNotEmpty &&
                        !filteredItems.any((it) => it.toLowerCase() == filter.trim().toLowerCase()))
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary,
                            child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          ),
                          title: Text(
                            'Use "${filter.trim()}"',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to select this custom item',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                          onTap: () {
                            onSelected(filter.trim());
                            Navigator.pop(ctx);
                          },
                        ),
                      ),

                    // Options List
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return ListTile(
                            leading: const Icon(Icons.school_outlined,
                                size: 20, color: AppTheme.primary),
                            title: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Month Picker Grid Modal ---
  void _openMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Birth Month',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _months.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemBuilder: (context, index) {
                    final month = _months[index];
                    final isSelected = _selectedMonth == month;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMonth = month;
                          _recalculateAge();
                        });
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          month,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Year Calendar Grid Modal with Decade Switcher (Concept 2) ---
  void _openYearPicker({
    required String title,
    required int? selectedYear,
    required int startYear,
    required int endYear,
    required ValueChanged<int> onYearSelected,
  }) {
    // Initial decade: default to selected year, or 2000s (candidate prime age), clamped between startYear & endYear
    final int defaultYear = selectedYear ?? (endYear >= 2000 && startYear <= 2000 ? 2000 : endYear);
    int currentDecadeStart = (defaultYear ~/ 10) * 10;
    if (currentDecadeStart < (startYear ~/ 10) * 10) {
      currentDecadeStart = (startYear ~/ 10) * 10;
    } else if (currentDecadeStart > (endYear ~/ 10) * 10) {
      currentDecadeStart = (endYear ~/ 10) * 10;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int decadeEnd = currentDecadeStart + 9;
            final bool canGoPrevious = currentDecadeStart > startYear;
            final bool canGoNext = decadeEnd < endYear;

            // Generate years belonging to this decade that fall within [startYear, endYear]
            final List<int> decadeYears = [];
            for (int y = currentDecadeStart; y <= decadeEnd; y++) {
              if (y >= startYear && y <= endYear) {
                decadeYears.add(y);
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top drag pill
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header with title and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Decade Stepper Bar with Left / Right Moving Arrows
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: canGoPrevious ? AppTheme.primary : const Color(0xFFCBD5E1),
                            ),
                            onPressed: canGoPrevious
                                ? () {
                                    setSheetState(() {
                                      currentDecadeStart -= 10;
                                    });
                                  }
                                : null,
                            tooltip: 'Previous Decade',
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                '$currentDecadeStart – $decadeEnd',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 18,
                              color: canGoNext ? AppTheme.primary : const Color(0xFFCBD5E1),
                            ),
                            onPressed: canGoNext
                                ? () {
                                    setSheetState(() {
                                      currentDecadeStart += 10;
                                    });
                                  }
                                : null,
                            tooltip: 'Next Decade',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Years Grid in Current Decade
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: decadeYears.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (context, index) {
                        final year = decadeYears[index];
                        final isSelected = selectedYear == year;
                        return GestureDetector(
                          onTap: () {
                            onYearSelected(year);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
                                width: isSelected ? 1.6 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$year',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Custom Date Picker Trigger Box ---
  Widget _buildPickerTriggerBox({
    required String? value,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool hasValue = value != null && value.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue ? AppTheme.primary : const Color(0xFFCBD5E1),
            width: hasValue ? 1.4 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? AppTheme.primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasValue ? value : placeholder,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: Color(0xFF64748B),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: _onPreviousStep,
        ),
        title: Text(
          _getStepTitle(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 600 : 440),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Step Progress Indicator (1 - 2 - 3 - 4)
                _buildStepProgressIndicator(),
                const SizedBox(height: 16),

                // Active Step Content in AnimatedSwitcher
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildCurrentStepView(),
                      ),
                    ),
                  ),
                ),

                // Bottom Navigation Row
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Personal Info';
      case 2:
        return 'Education Details';
      case 3:
        return 'What kind of work for you looking?';
      case 4:
        return 'Experience Details';
      default:
        return 'Candidate Profile';
    }
  }

  // --- Progress Indicator ---
  Widget _buildStepProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final stepNum = index + 1;
        final bool isActive = _currentStep == stepNum;
        final bool isPast = _currentStep > stepNum;

        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.primary
                    : isPast
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFE2E8F0),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppTheme.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isPast
                  ? const Icon(Icons.check, size: 16, color: AppTheme.success)
                  : Text(
                      '$stepNum',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
            ),
            if (index < 3)
              Container(
                width: 28,
                height: 2,
                color: isPast ? AppTheme.success : const Color(0xFFE2E8F0),
              ),
          ],
        );
      }),
    );
  }

  // --- Step Router ---
  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 1:
        return _buildStep1PersonalInfo();
      case 2:
        return _buildStep2Education();
      case 3:
        return _buildStep3JobTitles();
      case 4:
        return _buildStep4Experience();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1: PERSONAL INFO
  // ==========================================
  Widget _buildStep1PersonalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name
        _buildFieldLabel('Name*'),
        const SizedBox(height: 6),
        _buildOutlineInput(
          controller: _nameController,
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 16),

        // Mobile Number
        _buildFieldLabel('Mobile Number*'),
        const SizedBox(height: 6),
        _buildOutlineInput(
          controller: _phoneController,
          hint: 'Enter 10-digit mobile number',
          prefixIcon: Icons.phone_android_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Gender
        _buildFieldLabel('Gender*'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCustomRadioButton(
              label: 'Male',
              isSelected: _selectedGender == 'Male',
              onTap: () => setState(() => _selectedGender = 'Male'),
            ),
            const SizedBox(width: 24),
            _buildCustomRadioButton(
              label: 'Female',
              isSelected: _selectedGender == 'Female',
              onTap: () => setState(() => _selectedGender = 'Female'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Marital Status
        _buildFieldLabel('Marital Status*'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCustomRadioButton(
              label: 'Unmarried',
              isSelected: _selectedMaritalStatus == 'Unmarried',
              onTap: () => setState(() => _selectedMaritalStatus = 'Unmarried'),
            ),
            const SizedBox(width: 24),
            _buildCustomRadioButton(
              label: 'Married',
              isSelected: _selectedMaritalStatus == 'Married',
              onTap: () => setState(() => _selectedMaritalStatus = 'Married'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Location Card
        _buildFieldLabel('Your Location*'),
        const SizedBox(height: 8),

        // Detect My Current Location Button
        BouncyButton(
          onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
          borderRadius: BorderRadius.circular(10),
          pressOverlayColor: const Color(0xFF0C3E9E).withValues(alpha: 0.35),
          child: Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: _isDetectingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Detect My Current Location',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 14),

        // 1. State Selector
        _buildDropdownSelector(
          label: 'Your State*',
          value: _selectedState,
          icon: Icons.map_outlined,
          onClear: _selectedState.isNotEmpty
              ? () => setState(() {
                    _selectedState = '';
                    _selectedDistrict = '';
                    _selectedCity = '';
                  })
              : null,
          onTap: () {
            _openSearchablePicker(
              title: 'Choose Your State',
              items: LocationService.indianStates,
              onSelected: (val) {
                setState(() {
                  _selectedState = val;
                  // Auto-default district and default city for the selected state
                  final districts = LocationService.getDistrictsForState(val);
                  _selectedDistrict = districts.isNotEmpty ? districts.first : '$val Central';
                  _selectedCity = LocationService.getDefaultCityForDistrict(_selectedDistrict);
                });
              },
            );
          },
        ),
        const SizedBox(height: 14),

        // 2. District Selector
        _buildDropdownSelector(
          label: 'Your District*',
          value: _selectedDistrict,
          icon: Icons.location_on_outlined,
          onClear: _selectedDistrict.isNotEmpty
              ? () => setState(() {
                    _selectedDistrict = '';
                    _selectedCity = '';
                  })
              : null,
          onTap: () {
            if (_selectedState.isEmpty) {
              _showValidationToast('Please choose your State first');
              return;
            }
            _openSearchablePicker(
              title: 'Choose District in $_selectedState',
              items: LocationService.getDistrictsForState(_selectedState),
              onSelected: (val) {
                setState(() {
                  _selectedDistrict = val;
                  // Remove old city and change to the default city for this new district
                  _selectedCity = LocationService.getDefaultCityForDistrict(val);
                });
              },
            );
          },
        ),
        const SizedBox(height: 14),

        // 3. City / Town / Area Selector
        _buildDropdownSelector(
          label: 'Your City / Town / Area*',
          value: _selectedCity,
          icon: Icons.location_city_rounded,
          onClear: _selectedCity.isNotEmpty
              ? () => setState(() => _selectedCity = '')
              : null,
          onTap: () {
            if (_selectedDistrict.isEmpty) {
              _showValidationToast('Please choose your District first');
              return;
            }
            _openSearchablePicker(
              title: 'Choose City in $_selectedDistrict',
              items: LocationService.getCitiesForDistrict(_selectedDistrict),
              onSelected: (val) {
                setState(() => _selectedCity = val);
              },
            );
          },
        ),
        const SizedBox(height: 18),

        // Birth Month, Year & Calculated Age
        _buildFieldLabel('Birth Month and Year*'),
        const SizedBox(height: 8),
        Row(
          children: [
            // Month Calendar Box
            Expanded(
              flex: 5,
              child: _buildPickerTriggerBox(
                value: _selectedMonth,
                placeholder: 'Month*',
                icon: Icons.calendar_month_outlined,
                onTap: _openMonthPicker,
              ),
            ),
            const SizedBox(width: 10),
            // Year Calendar Box
            Expanded(
              flex: 4,
              child: _buildPickerTriggerBox(
                value: _selectedYear?.toString(),
                placeholder: 'Year*',
                icon: Icons.calendar_today_outlined,
                onTap: () {
                  final int currentYear = DateTime.now().year;
                  _openYearPicker(
                    title: 'Choose Birth Year',
                    selectedYear: _selectedYear,
                    startYear: currentYear - 100, // Max age 100 (automatically shifts in future years)
                    endYear: currentYear,
                    onYearSelected: (year) {
                      setState(() {
                        _selectedYear = year;
                        _recalculateAge();
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Calculated Age badge
            Expanded(
              flex: 3,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Age',
                        style: TextStyle(
                            fontSize: 10.5, color: Color(0xFF64748B))),
                    Text(
                      _calculatedAge != null ? '$_calculatedAge' : '--',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================
  // STEP 2: EDUCATION DETAILS
  // ==========================================
  Widget _buildStep2Education() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Education Box
        _buildFieldLabel('Education*'),
        const SizedBox(height: 8),
        _buildDropdownSelector(
          label: 'Education Level*',
          value: _selectedEducation,
          icon: Icons.school_outlined,
          onTap: () {
            _openSearchablePicker(
              title: 'Choose Your Education',
              items: _educationLevels,
              onSelected: (val) => setState(() => _selectedEducation = val),
            );
          },
        ),
        const SizedBox(height: 16),

        // Qualification Box
        _buildFieldLabel('Qualification*'),
        const SizedBox(height: 8),
        _buildDropdownSelector(
          label: 'Degree / Qualification*',
          value: _selectedQualification,
          icon: Icons.menu_book_rounded,
          onTap: () {
            _openSearchablePicker(
              title: 'Choose Your Qualification',
              items: _qualifications,
              onSelected: (val) => setState(() => _selectedQualification = val),
            );
          },
        ),
        const SizedBox(height: 16),

        // School/College Name
        _buildFieldLabel('College / Institution (Optional)'),
        const SizedBox(height: 8),
        _buildOutlineInput(
          controller: _collegeController,
          hint: 'e.g. Government Engineering College',
          prefixIcon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: 16),

        // Year of Passing
        _buildFieldLabel('Year of Passing*'),
        const SizedBox(height: 8),
        _buildPickerTriggerBox(
          value: _selectedGraduationYear?.toString(),
          placeholder: 'Select Passing Year*',
          icon: Icons.school_outlined,
          onTap: () {
            final int currentYear = DateTime.now().year;
            _openYearPicker(
              title: 'Choose Year of Passing',
              selectedYear: _selectedGraduationYear,
              startYear: currentYear - 60,
              endYear: currentYear + 5,
              onYearSelected: (year) {
                setState(() => _selectedGraduationYear = year);
              },
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================
  // STEP 3: JOB TITLES (MAX 4)
  // ==========================================
  Widget _buildStep3JobTitles() {
    final cleanQuery = _jobSearchQuery.trim();
    final filteredJobs = _masterJobTitles
        .where((title) =>
            title.toLowerCase().contains(cleanQuery.toLowerCase()))
        .toList();
    final bool isAlreadySelected = _selectedJobTitles
        .any((t) => t.toLowerCase() == cleanQuery.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Choose maximum 4 job titles',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              '${_selectedJobTitles.length}/4 Selected',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _selectedJobTitles.length == 4
                    ? AppTheme.primary
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Selected Chips Row
        if (_selectedJobTitles.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedJobTitles.map((title) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFB2DDFF), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedJobTitles.remove(title);
                        });
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 15, color: AppTheme.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Search job titles field
        TextField(
          controller: _jobSearchController,
          decoration: InputDecoration(
            hintText: 'Search or type any job title...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
            suffixIcon: cleanQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      _jobSearchController.clear();
                      setState(() => _jobSearchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          onChanged: (val) {
            setState(() => _jobSearchQuery = val);
          },
        ),

        // Option to add Custom Job Title if not already selected
        if (cleanQuery.isNotEmpty && !isAlreadySelected) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB2DDFF), width: 1.2),
            ),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
              title: Text(
                'Add "$cleanQuery" as custom role',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: const Text(
                'Tap to add this work to your preferred job titles',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
              ),
              onTap: () {
                if (_selectedJobTitles.length >= 4) {
                  _showValidationToast('Maximum 4 job titles allowed. Remove one to add this.');
                  return;
                }
                setState(() {
                  _selectedJobTitles.add(cleanQuery);
                  _jobSearchController.clear();
                  _jobSearchQuery = '';
                });
              },
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Job Titles List
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: filteredJobs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.work_off_outlined,
                            size: 38, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'No standard listing for "$cleanQuery"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap the "+ Add" card above to add it as your custom preferred role!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filteredJobs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final title = filteredJobs[index];
                    final isSelected = _selectedJobTitles.contains(title);

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.business_center_outlined,
                          size: 19, color: Color(0xFF64748B)),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppTheme.primary : const Color(0xFF1E293B),
                        ),
                      ),
                      trailing: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                if (_selectedJobTitles.length < 4) {
                                  _selectedJobTitles.add(title);
                                } else {
                                  _showValidationToast(
                                      'You can select a maximum of 4 job titles');
                                }
                              } else {
                                _selectedJobTitles.remove(title);
                              }
                            });
                          },
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedJobTitles.remove(title);
                          } else if (_selectedJobTitles.length < 4) {
                            _selectedJobTitles.add(title);
                          } else {
                            _showValidationToast('Maximum 4 job titles allowed');
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ==========================================
  // STEP 4: WORK EXPERIENCE
  // ==========================================
  Widget _buildStep4Experience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Column(
            children: [
              const Text(
                'Do you have any work experience?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCustomRadioButton(
                    label: 'NO (Fresher)',
                    isSelected: _hasWorkExperience == false,
                    onTap: () => setState(() => _hasWorkExperience = false),
                  ),
                  const SizedBox(width: 32),
                  _buildCustomRadioButton(
                    label: 'YES (Experienced)',
                    isSelected: _hasWorkExperience == true,
                    onTap: () => setState(() => _hasWorkExperience = true),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (_hasWorkExperience == false) ...[
          // Fresher Motivation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.primary, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fresher Friendly Opportunities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0C4A6E),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Career360 highlights verified entry-level roles, internships, and graduate programs for freshers.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF0369A1),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (_hasWorkExperience == true) ...[
          // Experience Form
          _buildFieldLabel('Total Experience*'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildExperienceStepper(
                  label: 'Years',
                  valueDisplay:
                      '$_experienceYearsCount ${_experienceYearsCount == 1 ? "Year" : "Years"}',
                  canDecrement: _experienceYearsCount > 0,
                  canIncrement: _experienceYearsCount < 40,
                  onDecrement: () => setState(() => _experienceYearsCount--),
                  onIncrement: () => setState(() => _experienceYearsCount++),
                  onTapValue: () => _openNumberInputDialog(
                    title: 'Years of Experience',
                    currentValue: _experienceYearsCount,
                    min: 0,
                    max: 40,
                    onConfirmed: (val) =>
                        setState(() => _experienceYearsCount = val),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildExperienceStepper(
                  label: 'Months',
                  valueDisplay:
                      '$_experienceMonthsCount ${_experienceMonthsCount == 1 ? "Month" : "Months"}',
                  canDecrement: _experienceMonthsCount > 0,
                  canIncrement: _experienceMonthsCount < 11,
                  onDecrement: () => setState(() => _experienceMonthsCount--),
                  onIncrement: () => setState(() => _experienceMonthsCount++),
                  onTapValue: () => _openNumberInputDialog(
                    title: 'Months of Experience',
                    currentValue: _experienceMonthsCount,
                    min: 0,
                    max: 11,
                    onConfirmed: (val) =>
                        setState(() => _experienceMonthsCount = val),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Current / Previous Company'),
          const SizedBox(height: 8),
          _buildOutlineInput(
            controller: _companyController,
            hint: 'e.g. Infosys / TCS / Cognizant',
            prefixIcon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Your Job Title / Designation'),
          const SizedBox(height: 8),
          _buildOutlineInput(
            controller: _jobTitleController,
            hint: 'e.g. Junior Web Developer',
            prefixIcon: Icons.work_outline_rounded,
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Current / Expected CTC (Salary)'),
          const SizedBox(height: 8),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _salaryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. 4.5',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                prefixIcon: const Icon(
                  Icons.currency_rupee_rounded,
                  size: 19,
                  color: AppTheme.primary,
                ),
                suffixIcon: Container(
                  margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFB2DDFF)),
                  ),
                  child: const Text(
                    'LPA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Notice Period'),
          const SizedBox(height: 8),
          _buildInlineDropdown(
            label: 'Availability*',
            value: _selectedNoticePeriod,
            hint: 'Select Notice Period',
            items: [
              'Immediate Joiner',
              '15 Days',
              '30 Days',
              '60 Days',
              '90 Days'
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedNoticePeriod = val);
            },
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Bottom Action Navigation Bar ---
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Step button
          TextButton(
            onPressed: _onPreviousStep,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                const SizedBox(width: 6),
                Text(
                  _currentStep == 1
                      ? 'Back to Login'
                      : _currentStep == 2
                          ? 'Personal Info'
                          : _currentStep == 3
                              ? 'Education'
                              : 'Job Titles',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Next / Finish Button
          BouncyButton(
            onPressed: _isSaving ? null : _onNextStep,
            borderRadius: BorderRadius.circular(12),
            pressOverlayColor: const Color(0xFF0C3E9E).withValues(alpha: 0.35),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentStep == 4 ? 'Finish' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 17, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers & Input Components ---
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildOutlineInput({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 19),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSelector({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? hint,
  }) {
    final bool hasValue = value.isNotEmpty;
    final display = hasValue ? value : (hint ?? 'Select $label');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasValue ? const Color(0xFFCBD5E1) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: hasValue ? AppTheme.primary : const Color(0xFF94A3B8),
                size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasValue && onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Icon(Icons.close_rounded,
                      color: Color(0xFF94A3B8), size: 18),
                ),
              ),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Color(0xFF64748B), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineDropdown({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      height: 50,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        hint: Text(
          hint,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCustomRadioButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : const Color(0xFF94A3B8),
                width: 1.8,
              ),
            ),
            alignment: Alignment.center,
            child: isSelected
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // --- Experience Stepper (Idea 2) ---
  Widget _buildExperienceStepper({
    required String label,
    required String valueDisplay,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required bool canDecrement,
    required bool canIncrement,
    VoidCallback? onTapValue,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Minus Button
              BouncyButton(
                onPressed: canDecrement ? onDecrement : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: canDecrement ? const Color(0xFFEFF8FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: canDecrement ? const Color(0xFFB2DDFF) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove_rounded,
                    size: 18,
                    color: canDecrement ? AppTheme.primary : const Color(0xFFCBD5E1),
                  ),
                ),
              ),

              // Value Display (Tappable for direct entry)
              GestureDetector(
                onTap: onTapValue,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    valueDisplay,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),

              // Plus Button
              BouncyButton(
                onPressed: canIncrement ? onIncrement : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: canIncrement ? AppTheme.primary : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: canIncrement ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Direct Number Input Dialog for Experience
  void _openNumberInputDialog({
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required ValueChanged<int> onConfirmed,
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter number ($min - $max)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null && val >= min && val <= max) {
                  onConfirmed(val);
                  Navigator.pop(ctx);
                } else {
                  _showValidationToast('Please enter a valid number between $min and $max');
                }
              },
              child: const Text('Set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }
}
