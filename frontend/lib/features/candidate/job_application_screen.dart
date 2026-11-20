import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/app_auth_bridge.dart';
import '../../data/models/job_model.dart';

class JobApplicationScreen extends StatefulWidget {
  final JobModel job;
  final String candidateUid;
  final VoidCallback onApplySuccess;

  const JobApplicationScreen({
    super.key,
    required this.job,
    required this.candidateUid,
    required this.onApplySuccess,
  });

  @override
  State<JobApplicationScreen> createState() => _JobApplicationScreenState();
}

class _JobApplicationScreenState extends State<JobApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _educationController;
  late TextEditingController _skillInputController;
  late TextEditingController _coverNoteController;

  String _selectedDistrict = 'Chennai';
  String _experienceLevel = '1 - 2 Years';
  String _noticePeriod = 'Immediate';

  final List<String> _skills = [];
  PlatformFile? _resumeFile;

  bool _isLoadingProfile = true;
  bool _isSubmitting = false;

  static const List<String> _experienceOptions = [
    'Fresher / Entry Level',
    'Less than 1 Year',
    '1 - 2 Years',
    '3 - 5 Years',
    '5+ Years',
  ];

  static const List<String> _noticeOptions = [
    'Immediate',
    '15 Days',
    '30 Days',
    'More than 30 Days',
  ];

  static const List<String> _suggestedSkills = [
    'Flutter',
    'React',
    'Node.js',
    'Python',
    'Java',
    'SQL',
    'Digital Marketing',
    'Sales',
    'Accounting',
    'Customer Support',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _educationController = TextEditingController();
    _skillInputController = TextEditingController();
    _coverNoteController = TextEditingController();

    _loadCandidateProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _educationController.dispose();
    _skillInputController.dispose();
    _coverNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidateProfile() async {
    final user = AppAuthBridge.currentUser;
    Map<String, dynamic>? profile;
    try {
      profile = await _supabaseService
          .streamCandidateProfile(widget.candidateUid)
          .first;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _nameController.text =
          profile?['fullName'] ?? user?.displayName ?? '';
      _emailController.text =
          profile?['email'] ?? user?.email ?? '';
      _phoneController.text =
          profile?['phone'] ?? '';
      _educationController.text =
          profile?['qualification'] ?? profile?['educationLevel'] ?? '';

      final rawDistrict = profile?['district']?.toString() ?? '';
      if (rawDistrict.isNotEmpty &&
          AppConstants.jobLocations.contains(rawDistrict) &&
          rawDistrict != 'All Locations') {
        _selectedDistrict = rawDistrict;
      } else {
        _selectedDistrict = widget.job.locationCity.contains('Erode')
            ? 'Erode'
            : (widget.job.locationCity.contains('Coimbatore')
                ? 'Coimbatore'
                : 'Chennai');
      }

      final rawExp = profile?['experienceYears']?.toString() ?? '';
      if (rawExp.isNotEmpty) {
        if (rawExp == '0') {
          _experienceLevel = 'Fresher / Entry Level';
        } else if (_experienceOptions.contains(rawExp)) {
          _experienceLevel = rawExp;
        }
      }

      _isLoadingProfile = false;
    });
  }

  Future<void> _pickResumeFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result.isNotEmpty) {
        final size = await result.first.length();
        if (size == null || size < 1 || size > 5 * 1024 * 1024) {
          throw StateError('Choose a resume smaller than 5 MB.');
        }
        setState(() {
          _resumeFile = result.first;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Attached: ${_resumeFile!.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $e')),
        );
      }
    }
  }

  void _removeResumeFile() {
    setState(() => _resumeFile = null);
  }

  void _addSkill(String skill) {
    final clean = skill.trim();
    if (clean.isNotEmpty && !_skills.contains(clean)) {
      setState(() {
        _skills.add(clean);
        _skillInputController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handleSubmitApplication() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }
    if (_resumeFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attach your resume before applying.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _supabaseService.applyToJob(
        jobId: widget.job.id,
        job: widget.job,
        candidateUid: widget.candidateUid,
        resumeFile: _resumeFile,
        candidateProfile: {
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'district': _selectedDistrict,
          'qualification': _educationController.text.trim(),
          'experienceYears': _experienceLevel,
          'noticePeriod': _noticePeriod,
          'skills': _skills,
          'coverNote': _coverNoteController.text.trim(),
        },
      );

      if (!mounted) return;

      if (!success) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission failed. Please verify your connection.'),
          ),
        );
        return;
      }

      widget.onApplySuccess();

      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Application Submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile and resume have been directly submitted to the hiring team at ${widget.job.companyName}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Return to Job Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validLocations = AppConstants.jobLocations
        .where((loc) => loc != 'All Locations')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Apply for Job',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary,
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Job Card Summary
                    _buildTargetJobCard(),
                    const SizedBox(height: 20),

                    // Section 1: Personal Details
                    _buildSectionHeader(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Information',
                      subtitle: 'Pre-filled from your profile. You can edit before applying.',
                    ),
                    const SizedBox(height: 12),
                    _buildPersonalDetailsCard(validLocations),
                    const SizedBox(height: 24),

                    // Section 2: Qualifications & Experience
                    _buildSectionHeader(
                      icon: Icons.school_outlined,
                      title: 'Qualifications & Experience',
                      subtitle: 'Specify your degree and practical experience level.',
                    ),
                    const SizedBox(height: 12),
                    _buildExperienceCard(),
                    const SizedBox(height: 24),

                    // Section 3: Skills & Expertise
                    _buildSectionHeader(
                      icon: Icons.bolt_outlined,
                      title: 'Skills & Expertise',
                      subtitle: 'Highlight key skills relevant to this opportunity.',
                    ),
                    const SizedBox(height: 12),
                    _buildSkillsCard(),
                    const SizedBox(height: 24),

                    // Section 4: Resume / CV Attachment
                    _buildSectionHeader(
                      icon: Icons.attach_file_rounded,
                      title: 'Resume / CV Attachment',
                      subtitle: 'Attach your latest resume (PDF, DOC, DOCX up to 5MB).',
                    ),
                    const SizedBox(height: 12),
                    _buildResumeCard(),
                    const SizedBox(height: 24),

                    // Section 5: Message to Recruiter
                    _buildSectionHeader(
                      icon: Icons.chat_outlined,
                      title: 'Note to Recruiter (Optional)',
                      subtitle: 'Introduce yourself or highlight why you are a great fit.',
                    ),
                    const SizedBox(height: 12),
                    _buildCoverNoteCard(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

      // Sticky Bottom Submit Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmitApplication,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF86EFAC),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetJobCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.job.companyName.isNotEmpty
                  ? widget.job.companyName[0].toUpperCase()
                  : 'C',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.job.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${widget.job.companyName} • ${widget.job.locationCity}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.job.salaryText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsCard(List<String> validLocations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          const Text(
            'Full Name *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration('Enter your full name'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: 14),

          // Email Address
          const Text(
            'Email Address *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration('Enter your email address'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Email is required' : null,
          ),
          const SizedBox(height: 14),

          // Phone / WhatsApp
          const Text(
            'Phone / WhatsApp Number *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration('Enter your phone number'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Phone number is required' : null,
          ),
          const SizedBox(height: 14),

          // District / Location
          const Text(
            'Current District / City',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: validLocations.contains(_selectedDistrict)
                ? _selectedDistrict
                : validLocations.first,
            decoration: _inputDecoration('Select location'),
            items: validLocations
                .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedDistrict = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Highest Qualification
          const Text(
            'Highest Education / Degree',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _educationController,
            decoration: _inputDecoration('e.g. B.E / B.Tech / BCA / B.Com / Diploma'),
          ),
          const SizedBox(height: 14),

          // Total Experience
          const Text(
            'Total Work Experience',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _experienceOptions.contains(_experienceLevel)
                ? _experienceLevel
                : _experienceOptions.first,
            decoration: _inputDecoration('Select experience level'),
            items: _experienceOptions
                .map((exp) => DropdownMenuItem(value: exp, child: Text(exp)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _experienceLevel = val);
            },
          ),
          const SizedBox(height: 14),

          // Notice Period
          const Text(
            'Notice Period',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _noticeOptions.contains(_noticePeriod)
                ? _noticePeriod
                : _noticeOptions.first,
            decoration: _inputDecoration('Select notice period'),
            items: _noticeOptions
                .map((np) => DropdownMenuItem(value: np, child: Text(np)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _noticePeriod = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Skills Chips
          if (_skills.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _skills.map((skill) {
                return Chip(
                  label: Text(
                    skill,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  deleteIcon: const Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  onDeleted: () => _removeSkill(skill),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Add New Skill Input
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _skillInputController,
                  decoration: _inputDecoration('Type a skill (e.g. Flutter, SQL)'),
                  onFieldSubmitted: _addSkill,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addSkill(_skillInputController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text(
                  '+ Add',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Suggestion Chips
          const Text(
            'Quick Suggestions:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestedSkills
                .where((s) => !_skills.contains(s))
                .take(6)
                .map((s) {
              return ActionChip(
                label: Text(
                  '+ $s',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFFF0FDF4),
                side: const BorderSide(color: Color(0xFFBBF7D0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onPressed: () => _addSkill(s),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: _resumeFile == null
          ? InkWell(
              onTap: _pickResumeFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.upload_file_rounded,
                      size: 38,
                      color: AppTheme.primary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Attach Resume / CV',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF, DOC, DOCX up to 5 MB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resumeFile!.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatFileSize(_resumeFile!.lengthSync() ?? 0)} • Attached',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _pickResumeFile,
                    child: const Text('Replace'),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    tooltip: 'Remove',
                    onPressed: _removeResumeFile,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCoverNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: _coverNoteController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText:
              'Mention your current availability, relevant projects, or why you are excited about this role...',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.all(12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }
}
