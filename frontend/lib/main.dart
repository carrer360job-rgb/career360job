import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/responsive/responsive_layout.dart';
import 'core/services/firestore_service.dart';
import 'core/widgets/bouncy_button.dart';
import 'data/models/job_model.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/candidate/candidate_guidelines_screen.dart';
import 'features/auth/candidate_login_screen.dart';
import 'features/candidate/candidate_onboarding_wizard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(const Career360App());
}

enum AppUserRole { candidate, employer, admin }

class Career360App extends StatefulWidget {
  const Career360App({super.key});

  @override
  State<Career360App> createState() => _Career360AppState();
}

class _Career360AppState extends State<Career360App> {
  bool _showSplash = true;
  bool _showCandidateGuidelines = false;
  bool _showCandidateLogin = false;
  bool _showCandidateOnboarding = false;
  AppUserRole? _currentRole;

  void _onSplashFinished() {
    setState(() {
      _showSplash = false;
    });
  }

  void _onRoleSelected(AppUserRole role) {
    if (role == AppUserRole.candidate) {
      setState(() {
        _showCandidateGuidelines = true;
      });
    } else {
      setState(() {
        _currentRole = role;
      });
    }
  }

  void _onCandidateGuidelinesAccepted() {
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = true;
    });
  }

  void _onCandidateGuidelinesBack() {
    setState(() {
      _showCandidateGuidelines = false;
      _currentRole = null;
    });
  }

  void _onCandidateLoginSuccess() {
    setState(() {
      _showCandidateLogin = false;
      _showCandidateOnboarding = true;
    });
  }

  void _onCandidateLoginBack() {
    setState(() {
      _showCandidateLogin = false;
      _showCandidateGuidelines = true;
    });
  }

  void _onCandidateOnboardingFinished() {
    setState(() {
      _showCandidateOnboarding = false;
      _currentRole = AppUserRole.candidate;
    });
  }

  void _onCandidateOnboardingBack() {
    setState(() {
      _showCandidateOnboarding = false;
      _showCandidateLogin = true;
    });
  }

  void _resetToRoleSelection() {
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = false;
      _showCandidateOnboarding = false;
      _currentRole = null;
    });
  }

  Widget _buildCurrentScreen() {
    if (_showSplash) {
      return SplashScreen(
        key: const ValueKey('splash_screen'),
        onFinish: _onSplashFinished,
      );
    }
    if (_showCandidateGuidelines) {
      return CandidateGuidelinesScreen(
        key: const ValueKey('guidelines_screen'),
        onAccepted: _onCandidateGuidelinesAccepted,
        onBack: _onCandidateGuidelinesBack,
      );
    }
    if (_showCandidateLogin) {
      return CandidateLoginScreen(
        key: const ValueKey('login_screen'),
        onLoginSuccess: _onCandidateLoginSuccess,
        onBack: _onCandidateLoginBack,
      );
    }
    if (_showCandidateOnboarding) {
      return CandidateOnboardingWizardScreen(
        key: const ValueKey('onboarding_wizard_screen'),
        onFinish: _onCandidateOnboardingFinished,
        onBackToLogin: _onCandidateOnboardingBack,
      );
    }
    if (_currentRole == null) {
      return RoleSelectionScreen(
        key: const ValueKey('role_selection_screen'),
        onSelectRole: _onRoleSelected,
      );
    }
    return MainShellScreen(
      key: ValueKey('main_shell_${_currentRole!.name}'),
      currentRole: _currentRole!,
      onRoleChanged: _onRoleSelected,
      onSwitchRoleRequested: _resetToRoleSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Career360 — Job Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.04, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ));
          return SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: _buildCurrentScreen(),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final AppUserRole currentRole;
  final ValueChanged<AppUserRole> onRoleChanged;
  final VoidCallback onSwitchRoleRequested;

  const MainShellScreen({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    required this.onSwitchRoleRequested,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'guest_candidate';

  int _selectedTabIndex = 0;
  String _selectedLocation = 'All Locations';
  String? _selectedCategory;
  String _searchQuery = '';
  final Set<String> _savedJobIds = {};
  final Set<String> _appliedJobIds = {};

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();

  // Employer Post Job Controllers
  final TextEditingController _postTitleController = TextEditingController();
  final TextEditingController _postCompanyController = TextEditingController();
  final TextEditingController _postSalaryController = TextEditingController();
  final TextEditingController _postVacanciesController = TextEditingController();
  final TextEditingController _postDescController = TextEditingController();
  String _postCategory = 'IT & Software';
  String _postLocation = 'Chennai';
  String _postWorkMode = 'Hybrid';
  bool _isPostingJob = false;

  StreamSubscription<Set<String>>? _savedSub;
  StreamSubscription<Set<String>>? _appliedSub;

  @override
  void initState() {
    super.initState();
    _firestoreService.seedInitialLiveJobsIfEmpty();
    _savedSub = _firestoreService.streamSavedJobIds(_currentUid).listen((ids) {
      if (mounted) setState(() => _savedJobIds..clear()..addAll(ids));
    });
    _appliedSub = _firestoreService.streamAppliedJobIds(_currentUid).listen((ids) {
      if (mounted) setState(() => _appliedJobIds..clear()..addAll(ids));
    });
  }

  @override
  void dispose() {
    _savedSub?.cancel();
    _appliedSub?.cancel();
    _searchController.dispose();
    _feedScrollController.dispose();
    _postTitleController.dispose();
    _postCompanyController.dispose();
    _postSalaryController.dispose();
    _postVacanciesController.dispose();
    _postDescController.dispose();
    super.dispose();
  }

  void _toggleSaveJob(String id) {
    final isSaved = _savedJobIds.contains(id);
    setState(() {
      if (isSaved) {
        _savedJobIds.remove(id);
      } else {
        _savedJobIds.add(id);
      }
    });
    _firestoreService.toggleSaveJob(
      candidateUid: _currentUid,
      jobId: id,
      isSaved: isSaved,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.primaryDark,
        content: Text(
          !isSaved ? 'Job saved to bookmarks' : 'Job removed from bookmarks',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _applyToJob(JobModel job) async {
    if (_appliedJobIds.contains(job.id)) return;
    setState(() {
      _appliedJobIds.add(job.id);
    });

    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? profile;
    try {
      profile = await _firestoreService.streamCandidateProfile(_currentUid).first;
    } catch (_) {}

    await _firestoreService.applyToJob(
      jobId: job.id,
      job: job,
      candidateUid: _currentUid,
      candidateProfile: {
        'fullName': profile?['fullName'] ?? user?.displayName ?? 'Applicant',
        'email': user?.email ?? '',
        'phone': profile?['phone'] ?? '',
        'qualification': profile?['qualification'] ?? profile?['educationLevel'] ?? '',
        'experienceYears': profile?['experienceYears'] ?? '0',
      },
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Application Submitted!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile and verified resume have been forwarded directly to the hiring team at ${job.companyName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Continue Exploring'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJobDetails(JobModel job) {
    final isApplied = _appliedJobIds.contains(job.id);
    final isSaved = _savedJobIds.contains(job.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildCompanyAvatar(job.companyName, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              job.companyName,
                              style: const TextStyle(fontSize: 14, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                        onPressed: () {
                          _toggleSaveJob(job.id);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(Icons.location_on_outlined, job.locationCity),
                      _buildChip(Icons.access_time_outlined, job.workMode),
                      _buildChip(Icons.currency_rupee, job.salaryText, isPrimary: true),
                      if (job.isVerified)
                        _buildChip(Icons.verified, 'Verified Recruiter', isSuccess: true),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Job Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    job.description,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  const Text('Key Requirements & Responsibilities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildRequirementBullet('Minimum 2+ years of verified industry experience in relevant technology stack.'),
                  _buildRequirementBullet('Strong communication skills, ability to collaborate across distributed teams.'),
                  _buildRequirementBullet('Bachelor’s degree or proven equivalent project portfolio demonstration.'),
                  _buildRequirementBullet('Demonstrated ownership of production-grade deliverable solutions.'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isApplied
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _applyToJob(job);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApplied ? Colors.grey.shade400 : AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isApplied ? 'Already Applied' : 'Apply for this Job ➔',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequirementBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, {bool isPrimary = false, bool isSuccess = false}) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppTheme.textPrimary;
    if (isPrimary) {
      bg = AppTheme.primaryLight;
      fg = AppTheme.primary;
    } else if (isSuccess) {
      bg = const Color(0xFFDCFCE7);
      fg = AppTheme.success;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Jobs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = 'All Locations';
                            _selectedCategory = null;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Preferred Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLocation,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: AppConstants.jobLocations.map((loc) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedLocation = val);
                        setModalState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Job Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'IT', 'Marketing', 'Finance', 'Design', 'Healthcare', 'Education'].map((cat) {
                      final isSelected = (_selectedCategory == cat) || (_selectedCategory == null && cat == 'All');
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat == 'All' ? null : cat;
                          });
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.notifications_active, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Notifications (2)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryLight,
                child: Icon(Icons.business, color: AppTheme.primary),
              ),
              title: const Text('Google Technologies', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Viewed your application for Senior UI/UX Designer', style: TextStyle(fontSize: 12)),
              trailing: const Text('2h ago', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.new_releases, color: AppTheme.success),
              ),
              title: const Text('New Matching Job Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Full Stack Flutter Developer in Bengaluru', style: TextStyle(fontSize: 12)),
              trailing: const Text('5h ago', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return PopScope(
      canPop: _selectedTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedTabIndex != 0) {
          setState(() {
            _selectedTabIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/career360_icon.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: const [
                Text(
                  'Career',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primaryDark),
                ),
                Text(
                  '360',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, color: AppTheme.textPrimary),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            onPressed: _showNotificationsDialog,
          ),
          IconButton(
            tooltip: 'Switch Mode',
            icon: const Icon(Icons.swap_horiz, color: AppTheme.primary),
            onPressed: widget.onSwitchRoleRequested,
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getRoleBadgeText(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(),
    ),
    );
  }

  String _getRoleBadgeText() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return 'Candidate';
      case AppUserRole.employer:
        return 'Recruiter ATS';
      case AppUserRole.admin:
        return 'Admin';
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar Navigation
        Container(
          width: 260,
          color: AppTheme.primaryDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _getRoleHeader(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._getNavItems().asMap().entries.map((entry) {
                final int idx = entry.key;
                final Map<String, dynamic> item = entry.value;
                final bool isSelected = _selectedTabIndex == idx;
                return ListTile(
                  leading: Icon(
                    item['icon'] as IconData,
                    color: isSelected ? AppTheme.accent : Colors.white70,
                  ),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  tileColor: isSelected ? Colors.white.withValues(alpha: 0.1) : null,
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = idx;
                    });
                  },
                );
              }),
            ],
          ),
        ),
        // Main View
        Expanded(
          child: Container(
            color: AppTheme.background,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey('${widget.currentRole.name}_$_selectedTabIndex'),
                    child: _getActiveScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey('${widget.currentRole.name}_$_selectedTabIndex'),
            child: _getActiveScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    final items = _getNavItems();
    return BottomNavigationBar(
      currentIndex: _selectedTabIndex,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textSecondary,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      onTap: (idx) {
        setState(() {
          _selectedTabIndex = idx;
        });
      },
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon'] as IconData),
          label: item['shortLabel'] as String,
        );
      }).toList(),
    );
  }

  String _getRoleHeader() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return 'JOB SEEKER WORKSPACE';
      case AppUserRole.employer:
        return 'RECRUITER ATS DESK';
      case AppUserRole.admin:
        return 'ADMIN CONTROL PANEL';
    }
  }

  List<Map<String, dynamic>> _getNavItems() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return [
          {'icon': Icons.home_filled, 'label': 'Home Discovery', 'shortLabel': 'Home'},
          {'icon': Icons.search, 'label': 'Search Jobs', 'shortLabel': 'Search'},
          {'icon': Icons.bookmark_outline, 'label': 'Saved Jobs', 'shortLabel': 'Saved'},
          {'icon': Icons.person_outline, 'label': 'Candidate Profile', 'shortLabel': 'Profile'},
        ];
      case AppUserRole.employer:
        return [
          {'icon': Icons.dashboard_outlined, 'label': 'Dashboard & Quota', 'shortLabel': 'Overview'},
          {'icon': Icons.post_add, 'label': 'Post a Job', 'shortLabel': 'Post Job'},
          {'icon': Icons.people_outline, 'label': 'Candidate Applicants', 'shortLabel': 'Applicants'},
        ];
      case AppUserRole.admin:
        return [
          {'icon': Icons.analytics_outlined, 'label': 'Platform Analytics', 'shortLabel': 'Stats'},
          {'icon': Icons.verified_user_outlined, 'label': 'Verify Employers', 'shortLabel': 'Verify'},
          {'icon': Icons.fact_check_outlined, 'label': 'Job Moderation', 'shortLabel': 'Moderate'},
        ];
    }
  }

  Widget _getActiveScreen() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        if (_selectedTabIndex == 0) return _buildCandidateHomeFeed();
        if (_selectedTabIndex == 1) return _buildCandidateSearchScreen();
        if (_selectedTabIndex == 2) return _buildCandidateSavedScreen();
        return _buildCandidateProfileScreen();

      case AppUserRole.employer:
        if (_selectedTabIndex == 0) return _buildEmployerOverview();
        if (_selectedTabIndex == 1) return _buildEmployerPostJob();
        return _buildEmployerApplicants();

      case AppUserRole.admin:
        return _buildAdminPanel();
    }
  }

  // --- CANDIDATE HOME FEED ---
  Widget _buildCandidateHomeFeed() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(
        category: _selectedCategory,
        locationCity: _selectedLocation,
        searchQuery: _searchQuery,
      ),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        return ListView(
          controller: _feedScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Greeting & Headline Streamed from Candidate Profile
            StreamBuilder<Map<String, dynamic>?>(
              stream: _firestoreService.streamCandidateProfile(_currentUid),
              builder: (context, profileSnap) {
                final profile = profileSnap.data;
                final fullName = profile?['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Candidate';
                final initials = fullName.trim().isNotEmpty
                    ? fullName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
                    : 'C3';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $fullName 👋',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Find Your Next\nCareer Move',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedTabIndex = 3);
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(
                          initials.isNotEmpty ? initials : 'C3',
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        const SizedBox(height: 16),

        // Search Input & Filter Button
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search jobs, skills, companies...',
                    hintStyle: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.search, color: AppTheme.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: IconButton(
                icon: const Icon(Icons.tune, color: AppTheme.primary, size: 20),
                onPressed: _showFilterModal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Featured Promo Card (Better Career, Brighter Future)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Better Career\nBrighter Future',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Apply today and grow faster!',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        _feedScrollController.animateTo(
                          420,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Explore Jobs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Top Categories Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                });
              },
              child: const Text('See All ➔', style: TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCategoryGrid(),
        const SizedBox(height: 22),

        // Recent Jobs Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Jobs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${jobs.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            if (_selectedCategory != null || _selectedLocation != 'All Locations')
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                    _selectedLocation = 'All Locations';
                  });
                },
                child: const Text('Clear Filters', style: TextStyle(fontSize: 12, color: AppTheme.error)),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Jobs Feed Cards
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (jobs.isEmpty)
          Container(
            padding: const EdgeInsets.all(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'No live jobs found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'There are no matching live jobs in Firestore for this filter. Reset filters to see all available vacancies.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedLocation = 'All Locations';
                      _selectedCategory = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  child: const Text('Reset All Filters'),
                ),
              ],
            ),
          )
        else
          ...jobs.map((job) => _buildReferenceJobCard(job)),
      ],
    );
      },
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {'name': 'IT & Software', 'icon': Icons.code, 'color': const Color(0xFFEFF8FF), 'iconColor': AppTheme.primary},
      {'name': 'Marketing', 'icon': Icons.campaign_outlined, 'color': const Color(0xFFFFF7ED), 'iconColor': const Color(0xFFEA580C)},
      {'name': 'Finance', 'icon': Icons.bar_chart_rounded, 'color': const Color(0xFFF0FDF4), 'iconColor': const Color(0xFF16A34A)},
      {'name': 'Design', 'icon': Icons.palette_outlined, 'color': const Color(0xFFFAF5FF), 'iconColor': const Color(0xFF9333EA)},
      {'name': 'Healthcare', 'icon': Icons.favorite_outline, 'color': const Color(0xFFFEF2F2), 'iconColor': const Color(0xFFDC2626)},
      {'name': 'Education', 'icon': Icons.school_outlined, 'color': const Color(0xFFFFFBEB), 'iconColor': const Color(0xFFD97706)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, idx) {
        final cat = categories[idx];
        final name = cat['name'] as String;
        final icon = cat['icon'] as IconData;
        final color = cat['color'] as Color;
        final iconColor = cat['iconColor'] as Color;
        final isSelected = _selectedCategory == name;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (_selectedCategory == name) {
                _selectedCategory = null;
              } else {
                _selectedCategory = name;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReferenceJobCard(JobModel job) {
    final isSaved = _savedJobIds.contains(job.id);
    final isApplied = _appliedJobIds.contains(job.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showJobDetails(job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar, Title, Bookmark
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompanyAvatar(job.companyName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                job.companyName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (job.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: AppTheme.primary),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? AppTheme.primary : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => _toggleSaveJob(job.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Location & Work Mode
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${job.locationCity} • ${job.workMode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: Salary Pill & Apply Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_rupee, size: 13, color: AppTheme.primary),
                          Text(
                            job.salaryText.replaceFirst('₹', ''),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isApplied ? null : () => _applyToJob(job),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isApplied ? const Color(0xFFDCFCE7) : AppTheme.primary,
                        foregroundColor: isApplied ? AppTheme.success : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isApplied ? 'Applied ✓' : 'Apply Now',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isApplied ? AppTheme.success : Colors.white,
                            ),
                          ),
                          if (!isApplied) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 13),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyAvatar(String companyName, {double size = 40}) {
    Color bg = const Color(0xFFEFF8FF);
    Color fg = AppTheme.primary;
    String letter = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';

    if (companyName.contains('Google')) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFFDC2626);
    } else if (companyName.contains('NexGen')) {
      bg = const Color(0xFFFAF5FF);
      fg = const Color(0xFF9333EA);
    } else if (companyName.contains('Horizon')) {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
    } else if (companyName.contains('Apollo')) {
      bg = const Color(0xFFF0FDF4);
      fg = const Color(0xFF16A34A);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }

  // --- CANDIDATE SEARCH SCREEN ---
  Widget _buildCandidateSearchScreen() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(
        category: _selectedCategory,
        locationCity: _selectedLocation,
        searchQuery: _searchQuery,
      ),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Explore All Opportunities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Real-time job opportunities streamed live from Cloud Firestore.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            // Search & Location Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search roles, skills, or companies...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: AppTheme.primary),
                    onPressed: _showFilterModal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (jobs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No matching live jobs found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Try adjusting your search terms or filters.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              )
            else ...[
              Text('${jobs.length} Results Found', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              ...jobs.map((job) => _buildReferenceJobCard(job)),
            ],
          ],
        );
      },
    );
  }

  // --- CANDIDATE SAVED SCREEN ---
  Widget _buildCandidateSavedScreen() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(),
      builder: (context, snapshot) {
        final allJobs = snapshot.data ?? [];
        final savedJobs = allJobs.where((j) => _savedJobIds.contains(j.id)).toList();

        if (savedJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bookmark_border_rounded, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No Saved Jobs Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Bookmark live opportunities while browsing to review and apply to them later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedTabIndex = 0),
                    child: const Text('Browse Job Feed'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Jobs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                Text('${savedJobs.length} Bookmarked', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            ...savedJobs.map((job) => _buildReferenceJobCard(job)),
          ],
        );
      },
    );
  }

  // --- CANDIDATE PROFILE SCREEN ---
  Widget _buildCandidateProfileScreen() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _firestoreService.streamCandidateProfile(_currentUid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final fullName = profile?['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'New Candidate';
        final phone = profile?['phone'] ?? 'No phone added';
        final qualification = profile?['qualification'] ?? profile?['educationLevel'] ?? '';
        final district = profile?['district'] ?? '';
        final city = profile?['city'] ?? '';
        final locationDisplay = district.isNotEmpty && city.isNotEmpty
            ? '$city, $district'
            : (district.isNotEmpty ? district : (city.isNotEmpty ? city : 'Tamil Nadu'));
        final hasExperience = profile?['hasExperience'] == true;
        final expText = hasExperience
            ? '${profile?['experienceYears'] ?? '1 Year'} • ${profile?['lastJobTitle'] ?? 'Experienced'}'
            : 'Fresher';
        final initials = fullName.trim().isNotEmpty
            ? fullName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
            : 'C3';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.primaryLight,
                    child: Text(
                      initials.isNotEmpty ? initials : 'C3',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$expText • $locationDisplay',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (qualification.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      qualification,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ProfileStat(label: 'Applied', value: '${_appliedJobIds.length}'),
                      _ProfileStat(label: 'Saved', value: '${_savedJobIds.length}'),
                      _ProfileStat(
                        label: 'Status',
                        value: profile != null ? 'Active' : 'Incomplete',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Wizard Launcher
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Candidate Details & Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Phone: $phone', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => CandidateOnboardingWizardScreen(
                            onFinish: () => Navigator.pop(c),
                            onBackToLogin: () => Navigator.pop(c),
                          ),
                        ),
                      );
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Role Switcher / Preferences
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.switch_account_outlined, color: AppTheme.primary),
                    title: const Text('Switch Role Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Access Employer ATS or Admin Control Panel', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onSwitchRoleRequested,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.textPrimary),
                    title: const Text('Candidate Guidelines & Safety', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => CandidateGuidelinesScreen(
                            onAccepted: () => Navigator.pop(c),
                            onBack: () => Navigator.pop(c),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- EMPLOYER VIEWS ---
  Widget _buildEmployerOverview() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(),
      builder: (context, jobsSnap) {
        final jobCount = jobsSnap.data?.length ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.streamRecruiterApplicants(),
          builder: (context, appSnap) {
            final appCount = appSnap.data?.length ?? 0;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recruiter ATS Dashboard',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live Firestore Integration • Real-Time Candidate Applications',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(label: 'Live Jobs', value: '$jobCount', highlight: true),
                          _MetricItem(label: 'Total Applicants', value: '$appCount', highlight: true),
                          const _MetricItem(label: 'ATS Status', value: 'Active'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quick Recruiter Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => setState(() => _selectedTabIndex = 1),
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Post Job'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _selectedTabIndex = 2),
                              icon: const Icon(Icons.people_alt_outlined, size: 18),
                              label: const Text('Applicants'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateJobPost() async {
    final title = _postTitleController.text.trim();
    final company = _postCompanyController.text.trim();
    final salary = _postSalaryController.text.trim();
    final vacancies = int.tryParse(_postVacanciesController.text.trim()) ?? 1;
    final desc = _postDescController.text.trim();

    if (title.isEmpty || company.isEmpty || salary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Please fill in Job Title, Company Name, and Salary Range.'),
        ),
      );
      return;
    }

    setState(() => _isPostingJob = true);

    try {
      final newJob = JobModel(
        id: '',
        title: title,
        companyName: company,
        locationCity: _postLocation,
        salaryText: salary.startsWith('₹') ? salary : '₹$salary',
        category: _postCategory,
        workMode: _postWorkMode,
        vacanciesCount: vacancies,
        description: desc.isNotEmpty
            ? desc
            : 'We are seeking a talented $title to join our growing team at $company.',
        employerUid: _currentUid,
        isVerified: true,
        postedAt: DateTime.now(),
      );

      await _firestoreService.createJobPost(newJob);

      if (!mounted) return;
      setState(() {
        _isPostingJob = false;
        _postTitleController.clear();
        _postCompanyController.clear();
        _postSalaryController.clear();
        _postVacanciesController.clear();
        _postDescController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Job posted successfully to Cloud Firestore!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingJob = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Failed to publish job: $e'),
          ),
        );
      }
    }
  }

  Widget _buildEmployerPostJob() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Job Vacancy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Publish vacancies live to all registered candidates in Cloud Firestore.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),

              // Job Title
              const Text('Job Title*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _postTitleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Senior Flutter Developer',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Company Name
              const Text('Company Name*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _postCompanyController,
                decoration: InputDecoration(
                  hintText: 'e.g. Zoho Corporation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Category & Work Mode Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'IT & Software', child: Text('IT & Software', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Marketing', child: Text('Marketing', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Finance', child: Text('Finance', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Design', child: Text('Design', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Education', child: Text('Education', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _postCategory = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Work Mode*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postWorkMode,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Remote', child: Text('Remote', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'On-Site', child: Text('On-Site', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _postWorkMode = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location & Salary Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Location City*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postLocation,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Chennai', child: Text('Chennai', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Coimbatore', child: Text('Coimbatore', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Bengaluru', child: Text('Bengaluru', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Erode', child: Text('Erode', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Salem', child: Text('Salem', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'Madurai', child: Text('Madurai', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _postLocation = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Salary Text*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _postSalaryController,
                          decoration: InputDecoration(
                            hintText: 'e.g. ₹8 - 14 LPA',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vacancies Count
              const Text('Vacancies Available', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _postVacanciesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 2',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text('Job Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _postDescController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Key responsibilities, stack requirements, and candidate qualifications...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              BouncyButton(
                onPressed: _isPostingJob ? null : _handleCreateJobPost,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPostingJob
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : const Text(
                          'Publish Job to Firestore ➔',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployerApplicants() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamRecruiterApplicants(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final applicants = snapshot.data ?? [];

        if (applicants.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inbox_rounded, size: 60, color: AppTheme.textSecondary),
                  SizedBox(height: 14),
                  Text('No Applicants Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'When candidates apply to live jobs, their profiles will appear here instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applicants.length,
          itemBuilder: (context, idx) {
            final app = applicants[idx];
            final name = app['candidateName'] ?? 'Applicant';
            final jobTitle = app['jobTitle'] ?? 'Job';
            final email = app['candidateEmail'] ?? '';
            final phone = app['candidatePhone'] ?? '';
            final education = app['education'] ?? '';
            final status = app['status'] ?? 'Applied';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied for: $jobTitle',
                    style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (phone.isNotEmpty || email.isNotEmpty)
                    Text(
                      'Contact: ${phone.isNotEmpty ? phone : ''} ${email.isNotEmpty ? '• $email' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  if (education.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Education: $education',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- ADMIN VIEWS ---
  Widget _buildAdminPanel() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(),
      builder: (context, jobSnap) {
        final totalJobs = jobSnap.data?.length ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.streamRecruiterApplicants(),
          builder: (context, appSnap) {
            final totalApps = appSnap.data?.length ?? 0;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Governance & Master Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(label: 'Live Jobs', value: '$totalJobs', highlight: true),
                          _MetricItem(label: 'Applications', value: '$totalApps', highlight: true),
                          const _MetricItem(label: 'System Status', value: 'Live 100%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricItem({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: highlight ? AppTheme.primary : AppTheme.primaryDark)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}
