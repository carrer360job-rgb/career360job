import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/services/candidate_photo_service.dart';
import '../../core/services/employer_service.dart';
import '../../core/services/employer_logo_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';
import '../notifications/notification_center_screen.dart';
import 'employer_job_form_screen.dart';
import 'employer_registration_screen.dart';
import 'employer_plan_screen.dart';

class EmployerWorkspaceScreen extends StatefulWidget {
  final EmployerProfile profile;
  final VoidCallback onSignOut;
  final VoidCallback? onProfileUpdated;

  const EmployerWorkspaceScreen({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.onProfileUpdated,
  });

  @override
  State<EmployerWorkspaceScreen> createState() =>
      _EmployerWorkspaceScreenState();
}

class _EmployerWorkspaceScreenState extends State<EmployerWorkspaceScreen> {
  final _service = EmployerService();
  final _logoService = EmployerLogoService();
  final _api = EmployerApiService();
  late Stream<List<JobModel>> _jobsStream;
  late Stream<List<Map<String, dynamic>>> _applicationsStream;
  Future<Map<String, dynamic>>? _entitlementFuture;
  int _tab = 0;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(PushNotificationService.instance.registerAfterPortalEntry());
      }
    });
    _jobsStream = _service.watchJobs(widget.profile.uid);
    _applicationsStream = widget.profile.isApproved
        ? _service.watchApplications(widget.profile.uid)
        : Stream.value(const <Map<String, dynamic>>[]);
    if (widget.profile.isApproved) _entitlementFuture = _api.entitlement();
  }

  @override
  void didUpdateWidget(covariant EmployerWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.uid != widget.profile.uid) {
      _jobsStream = _service.watchJobs(widget.profile.uid);
    }
    if (oldWidget.profile.uid != widget.profile.uid ||
        oldWidget.profile.isApproved != widget.profile.isApproved) {
      _applicationsStream = widget.profile.isApproved
          ? _service.watchApplications(widget.profile.uid)
          : Stream.value(const <Map<String, dynamic>>[]);
      _entitlementFuture = widget.profile.isApproved ? _api.entitlement() : null;
    }
  }

  void _message(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  void _openPlans() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EmployerPlanScreen(profile: widget.profile),
    ),
  );

  void _openJobForm([JobModel? job]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployerJobFormScreen(
          profile: widget.profile,
          existingJob: job,
          onPlanNeeded: _openPlans,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.profile.uid;
    final labels = ['Overview', 'Jobs', 'Applicants', 'Company'];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Career360',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              widget.profile.companyName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _planHeaderPill(widget.profile),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationCenterScreen(uid: uid),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<JobModel>>(
          stream: _jobsStream,
          builder: (context, jobsSnapshot) =>
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _applicationsStream,
                builder: (context, applicationsSnapshot) {
                  if (jobsSnapshot.hasError || applicationsSnapshot.hasError) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded, size: 36),
                      const SizedBox(height: 10),
                      const Text('Could not load your workspace'),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: () => setState(() {
                        _jobsStream = _service.watchJobs(widget.profile.uid);
                        _applicationsStream = widget.profile.isApproved
                            ? _service.watchApplications(widget.profile.uid)
                            : Stream.value(const <Map<String, dynamic>>[]);
                      }), child: const Text('Retry')),
                    ]));
                  }
                  if (!jobsSnapshot.hasData || !applicationsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final jobs = jobsSnapshot.data!;
                  final applications = applicationsSnapshot.data!;
                  return switch (_tab) {
                    0 => _overview(jobs, applications),
                    1 => _jobs(jobs),
                    2 => _applicants(applications),
                    _ => _company(),
                  };
                },
              ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          const NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Applicants',
          ),
          NavigationDestination(
            icon: const Icon(Icons.business_outlined),
            selectedIcon: const Icon(Icons.business_rounded),
            label: labels[3],
          ),
        ],
      ),
    );
  }

  Widget _overview(
    List<JobModel> jobs,
    List<Map<String, dynamic>> applications,
  ) {
    final profile = widget.profile;
    final live = jobs.where((job) => job.isOpen).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
      children: [
        Text(
          'Good to see you, ${profile.contactName.split(' ').first}',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Manage hiring from one place.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 18),
        if (profile.status == 'rejected') _reviewCard(profile),
        _heroCard(profile, live, applications.length),
        const SizedBox(height: 20),
        const _SectionTitle('Hiring at a glance'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Live jobs',
                value: '$live',
                icon: Icons.work_outline_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Applicants',
                value: '${applications.length}',
                icon: Icons.people_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Credits',
                value: profile.hasActiveCredits
                    ? '${profile.postingCredits}'
                    : '0',
                icon: Icons.local_offer_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Closed jobs',
                value: '${jobs.where((j) => !j.isOpen).length}',
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle('Recent applications'),
        const SizedBox(height: 9),
        if (applications.isEmpty)
          const _StatePanel(
            icon: Icons.inbox_outlined,
            title: 'No applicants yet',
            detail: 'Applications for your published jobs will appear here.',
          ),
        for (final application in applications.take(3))
          _applicantCard(application),
        if (applications.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _tab = 2),
            child: const Text('View all applicants'),
          ),
      ],
    );
  }

  Widget _reviewCard(EmployerProfile profile) {
    return const Card(
      color: Color(0xFFFEF2F2),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.error),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Company account needs attention',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Contact Career360 support to update your company details.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(
    EmployerProfile profile,
    int live,
    int applicants,
  ) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppTheme.primaryDark,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.campaign_outlined, color: AppTheme.accent, size: 30),
        const SizedBox(height: 12),
        Text(
          !profile.isApproved
              ? 'Company details received'
              : live == 0
              ? 'Find your next great hire'
              : 'Keep your hiring moving',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          !profile.isApproved
              ? 'Your details are saved. Review them in the Company tab while your account awaits approval.'
              : live == 0
              ? 'Publish a job and reach Career360 candidates across Tamil Nadu.'
              : '$live live jobs · $applicants applications',
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
        ),
        const SizedBox(height: 17),
        if (profile.isApproved) FilledButton.icon(
          onPressed: () => _openJobForm(),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryDark,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Post a job'),
        ),
        if (profile.isApproved && !profile.hasActiveCredits)
          TextButton(
            onPressed: _openPlans,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('See posting plans →'),
          ),
      ],
    ),
  );

  Widget _planHeaderPill(EmployerProfile profile) {
    final hasCredits = profile.hasActiveCredits;
    final isElite = profile.isElitePlan;
    final isFeatured = profile.isFeaturedPlan;

    final String label;
    final IconData icon;
    final Color bg;
    final Color fg;
    final Color border;

    if (isElite) {
      label = 'Elite · ${profile.postingCredits}';
      icon = Icons.workspace_premium_rounded;
      bg = const Color(0xFFF5F3FF);
      fg = const Color(0xFF7C3AED);
      border = const Color(0xFFDDD6FE);
    } else if (isFeatured) {
      label = 'Premium · ${profile.postingCredits}';
      icon = Icons.star_rounded;
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFED7AA);
    } else if (hasCredits) {
      final name = profile.activePlanName.isNotEmpty
          ? profile.activePlanName.split(' ').first
          : 'Plan';
      label = '$name · ${profile.postingCredits}';
      icon = Icons.bolt_rounded;
      bg = const Color(0xFFEFF6FF);
      fg = AppTheme.primary;
      border = const Color(0xFFBFDBFE);
    } else {
      label = 'Upgrade ↗';
      icon = Icons.bolt_rounded;
      bg = const Color(0xFFF8FAFC);
      fg = const Color(0xFF1E293B);
      border = const Color(0xFFCBD5E1);
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPlans,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _jobs(List<JobModel> jobs) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
    children: [
      Row(
        children: [
          const Expanded(child: _SectionTitle('Your jobs')),
          if (widget.profile.isApproved)
            FilledButton.icon(
              onPressed: () => _openJobForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Post job'),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (jobs.isEmpty)
        const _StatePanel(
          icon: Icons.work_outline_rounded,
          title: 'No jobs posted',
          detail: 'Your first published role will appear here.',
        ),
      for (final job in jobs)
        Card(
          margin: const EdgeInsets.only(bottom: 11),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _StatusPill(
                      text: job.isOpen ? 'Live' : 'Closed',
                      positive: job.isOpen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${job.locationCity} · ${job.workMode} · ${job.salaryText}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${job.vacanciesCount} opening${job.vacanciesCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (job.isOpen)
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => _openJobForm(job),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => _confirmClose(job),
                        child: const Text('Close job'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
    ],
  );

  Future<void> _confirmClose(JobModel job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this job?'),
        content: const Text(
          'Candidates will no longer be able to apply. This will not return a posting credit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.closeJob(job.id);
    } catch (error) {
      _message(error);
    }
  }

  Widget _applicants(List<Map<String, dynamic>> applications) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
    children: [
      const _SectionTitle('Applicants'),
      const SizedBox(height: 4),
      const Text(
        'Review candidates and move them through hiring.',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      if (_entitlementFuture != null) FutureBuilder<Map<String, dynamic>>(
        future: _entitlementFuture,
        builder: (context, snapshot) {
          final entitlement = snapshot.data?['entitlement'];
          if (entitlement is! Map) return const SizedBox.shrink();
          final limit = entitlement['profileUnlockLimit'] as int? ?? 0;
          final used = entitlement['unlocksUsed'] as int? ?? 0;
          return Padding(padding: const EdgeInsets.only(top: 10),
            child: Text('${limit - used} of $limit profile unlocks left in this plan',
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)));
        },
      ),
      const SizedBox(height: 16),
      if (applications.isEmpty)
        const _StatePanel(
          icon: Icons.people_outline_rounded,
          title: 'No applications yet',
          detail: 'Applicants will appear as people apply to your jobs.',
        ),
      for (final application in applications) _applicantCard(application),
    ],
  );

  Widget _applicantCard(Map<String, dynamic> application) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmployerApplicantScreen(application: application),
        ),
        );
        if (mounted && widget.profile.isApproved) {
          setState(() {
            _entitlementFuture = _api.entitlement();
            _applicationsStream = _service.watchApplications(widget.profile.uid);
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                _initial(application['candidateName']),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${application['candidateName'] ?? 'Applicant'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${application['jobTitle'] ?? 'Job'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );

  String _initial(Object? name) {
    final text = (name ?? 'A').toString().trim();
    return text.isEmpty ? 'A' : text[0].toUpperCase();
  }

  Future<void> _openCompanyProfileEditor(EmployerProfile profile) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => EmployerRegistrationScreen(
          initialProfile: profile,
          onSignOut: () => Navigator.pop(routeContext),
          onSubmissionStarted: () {},
          onSubmissionFailed: () {},
          onFinished: () => Navigator.pop(routeContext, true),
        ),
      ),
    );
    if (mounted && updated == true) widget.onProfileUpdated?.call();
  }

  Future<void> _showLogoActions(EmployerProfile profile) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined, color: AppTheme.primary),
              title: Text(profile.logoUrl.isEmpty ? 'Add company logo' : 'Change company logo'),
              subtitle: const Text('JPG, PNG, or WebP · up to 3 MB'),
              onTap: () => Navigator.pop(sheetContext, 'upload'),
            ),
            if (profile.logoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: const Text('Remove company logo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'upload') {
      await _pickAndUploadLogo(profile.uid);
    } else if (action == 'remove') {
      await _removeLogo(profile.uid);
    }
  }

  Future<void> _pickAndUploadLogo(String uid) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
    } catch (_) {
      _showCompanyMessage('Could not open the image picker. Try again.');
      return;
    }
    if (file == null || !mounted) return;

    final Uint8List bytes;
    try {
      final size = await file.length();
      if (size == null || size == 0 || size > 3 * 1024 * 1024) {
        _showCompanyMessage('Choose an image under 3 MB.');
        return;
      }
      bytes = await file.readAsBytes();
      CandidatePhotoService.imageExtension(bytes);
    } catch (_) {
      _showCompanyMessage('Choose a valid JPG, PNG, or WebP image.');
      return;
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use this company logo?'),
        content: ClipOval(
          child: Image.memory(
            bytes,
            width: 130,
            height: 130,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.broken_image_outlined, size: 80),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upload logo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingLogo = true);
    try {
      await _logoService.upload(uid: uid, bytes: bytes);
      if (mounted) {
        widget.onProfileUpdated?.call();
        _showCompanyMessage('Company logo updated.');
      }
    } catch (error) {
      _showCompanyMessage(error is StateError
          ? error.message
          : 'Could not upload your logo. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _removeLogo(String uid) async {
    setState(() => _isUploadingLogo = true);
    try {
      await _logoService.delete(uid);
      if (mounted) {
        widget.onProfileUpdated?.call();
        _showCompanyMessage('Company logo removed.');
      }
    } catch (error) {
      _showCompanyMessage(error is StateError
          ? error.message
          : 'Could not remove your logo. Try again.');
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  void _showCompanyMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _companyHeader(EmployerProfile profile) {
    final name = profile.companyName.trim().isEmpty
        ? 'Company'
        : profile.companyName.trim();

    final industryText = profile.industry.trim().isNotEmpty
        ? profile.industry.trim()
        : (profile.district.trim().isNotEmpty
            ? '${profile.district}, ${profile.state}'
            : 'Information Technology & Services');

    Widget fallbackLogo() => Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.apartment_rounded,
        color: AppTheme.primary,
        size: 34,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Logo | Vertical Divider | Company Details | Squircle Edit Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Company Logo
              GestureDetector(
                onTap: _isUploadingLogo ? null : () => _showLogoActions(profile),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDBEAFE),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: profile.logoUrl.isNotEmpty
                      ? Image.network(
                          profile.logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallbackLogo(),
                        )
                      : fallbackLogo(),
                ),
              ),
              const SizedBox(width: 14),
              // Subtle vertical divider line
              Container(
                width: 1,
                height: 52,
                color: const Color(0xFFE2E8F0),
              ),
              const SizedBox(width: 14),
              // Name, Industry, and Status Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      industryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildCompanyStatusBadge(profile),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Squircle edit/camera icon button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isUploadingLogo ? null : () => _showLogoActions(profile),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _isUploadingLogo
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.edit_outlined,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          // Bottom Dual Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _tab = 1),
                  icon: const Icon(Icons.work_outline_rounded, size: 18),
                  label: const Text('Your Jobs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openCompanyProfileEditor(profile),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyStatusBadge(EmployerProfile profile) {
    final bool isRejected = profile.status == 'rejected';
    final bool isApproved = profile.isApproved;

    final Color bgColor = isRejected
        ? const Color(0xFFFFE4E6)
        : isApproved
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF3C7);

    final Color textColor = isRejected
        ? const Color(0xFFBE123C)
        : isApproved
            ? const Color(0xFF15803D)
            : const Color(0xFFB45309);

    final IconData icon = isRejected
        ? Icons.error_outline_rounded
        : isApproved
            ? Icons.verified_rounded
            : Icons.access_time_rounded;

    final String label = isRejected
        ? 'Needs attention'
        : isApproved
            ? 'Verified Company'
            : 'Awaiting review';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _companyValue(String value) =>
      value.trim().isEmpty ? 'Not provided' : value.trim();

  Widget _companyFactsSection({
    required String title,
    required IconData icon,
    required List<(String, String)> fields,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 19, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fields[index].$1,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fields[index].$2,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < fields.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppTheme.border.withValues(alpha: 0.55),
                ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _company() {
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _companyHeader(profile),
        const SizedBox(height: 22),
        const Text(
          'Profile details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _companyFactsSection(
          title: 'Company information',
          icon: Icons.business_outlined,
          fields: [
            ('Industry', _companyValue(profile.industry)),
            ('Company size', _companyValue(profile.companySize)),
            ('Description', _companyValue(profile.description)),
            ('Website', _companyValue(profile.website)),
            if (profile.registrationNumber.isNotEmpty)
              ('Registration ID', profile.registrationNumber),
          ],
        ),
        const SizedBox(height: 16),
        _companyFactsSection(
          title: 'Recruiter information',
          icon: Icons.person_outline_rounded,
          fields: [
            ('Contact name', _companyValue(profile.contactName)),
            ('Designation', _companyValue(profile.designation)),
            ('Email', _companyValue(profile.email)),
            ('Phone number', _companyValue(profile.phone)),
            (
              'WhatsApp contact',
              profile.whatsappSameAsPhone
                  ? 'Same as mobile number'
                  : 'Different WhatsApp number',
            ),
            ('WhatsApp number', _companyValue(profile.whatsappPhone)),
          ],
        ),
        const SizedBox(height: 16),
        _companyFactsSection(
          title: 'Location',
          icon: Icons.location_on_outlined,
          fields: [
            ('Address', _companyValue(profile.address)),
            if (profile.city.isNotEmpty) ('City', profile.city),
            ('District', _companyValue(profile.district)),
            ('State', _companyValue(profile.state)),
            ('PIN code', _companyValue(profile.postalCode)),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle('Subscription & Billing'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: profile.isElitePlan
                        ? const Color(0xFFF5F3FF)
                        : profile.isFeaturedPlan
                        ? const Color(0xFFFFFBEB)
                        : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    profile.isElitePlan
                        ? Icons.workspace_premium_rounded
                        : profile.isFeaturedPlan
                        ? Icons.star_rounded
                        : Icons.card_membership_rounded,
                    color: profile.isElitePlan
                        ? const Color(0xFF7C3AED)
                        : profile.isFeaturedPlan
                        ? const Color(0xFFD97706)
                        : AppTheme.primary,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.activePlanName.isEmpty
                            ? 'No active plan'
                            : profile.activePlanName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: profile.isElitePlan
                            ? const Color(0xFF7C3AED)
                            : profile.isFeaturedPlan
                            ? const Color(0xFFF59E0B)
                            : AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        profile.planBadgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: (profile.isElitePlan || profile.isFeaturedPlan)
                              ? Colors.white
                              : AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${profile.postingCredits} credit(s) available · ${profile.listingDays} days listing duration',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                trailing: TextButton(
                  onPressed: _openPlans,
                  child: const Text('Change'),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Payment History & Invoices'),
                subtitle: const Text(
                  'View receipts and completed transactions',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EmployerPaymentHistoryScreen(uid: profile.uid),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        TextButton.icon(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Sign out'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.error,
            minimumSize: const Size.fromHeight(46),
          ),
        ),
      ],
    );
  }
}

class EmployerApplicantScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  const EmployerApplicantScreen({super.key, required this.application});
  @override
  State<EmployerApplicantScreen> createState() =>
      _EmployerApplicantScreenState();
}

class _EmployerApplicantScreenState extends State<EmployerApplicantScreen> {
  final _api = EmployerApiService();
  bool _busy = false;
  bool _unlocked = false;
  Map<String, dynamic>? _profile;
  late String _status = '${widget.application['status'] ?? 'Applied'}';

  @override
  void initState() {
    super.initState();
    _unlocked = widget.application['unlocked'] == true;
    if (_unlocked) _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.applicantProfile('${widget.application['id']}');
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) _show(error);
    }
  }

  Future<void> _unlock() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Unlock applicant profile?'),
      content: const Text('This uses one profile unlock from your current plan. The applicant’s contact details and photo will be available until the plan expires.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unlock')),
      ],
    ));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.unlockApplicant('${widget.application['id']}');
      final profile = await _api.applicantProfile('${widget.application['id']}');
      if (mounted) setState(() { _unlocked = true; _profile = profile; });
    } catch (error) {
      if (mounted) _show(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _api.updateApplication('${widget.application['id']}', status);
      if (mounted) setState(() => _status = status);
    } catch (error) {
      _show(error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _show(Object error) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
  );

  @override
  Widget build(BuildContext context) {
    final a = widget.application;
    return Scaffold(
      appBar: AppBar(title: const Text('Applicant details')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_unlocked && _profile?['profilePhotoUrl'] is String &&
                      (_profile!['profilePhotoUrl'] as String).isNotEmpty) ...[
                    CircleAvatar(radius: 26,
                      backgroundImage: NetworkImage(_profile!['profilePhotoUrl'] as String)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '${a['candidateName'] ?? 'Applicant'}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Applied for ${a['jobTitle'] ?? 'job'}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _StatusPill(text: _status, positive: _status != 'Rejected'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_unlocked) Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Contact details and photo are available after a profile unlock.'),
              const SizedBox(height: 10),
              FilledButton.icon(onPressed: _busy ? null : _unlock,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Unlock profile')),
            ]),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(_unlocked ? '${_profile?['email'] ?? 'Loading…'}' : 'Locked'),
                ),
                ListTile(
                  leading: const Icon(Icons.call_outlined),
                  title: const Text('Phone'),
                  subtitle: Text(_unlocked ? '${_profile?['phone'] ?? 'Loading…'}' : 'Locked'),
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Qualification'),
                  subtitle: Text('${a['education'] ?? 'Not provided'}'),
                ),
                ListTile(
                  leading: const Icon(Icons.business_center_outlined),
                  title: const Text('Experience'),
                  subtitle: Text(
                    '${a['experienceYears'] ?? 'Not provided'} years',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 20),
          const _SectionTitle('Move application'),
          const SizedBox(height: 10),
          for (final status in [
            'Shortlisted',
            'Interview',
            'Hired',
            'Rejected',
          ])
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(status),
                trailing: _status == status
                    ? const Icon(Icons.check_circle, color: AppTheme.success)
                    : const Icon(Icons.chevron_right),
                onTap: _busy || _status == status
                    ? null
                    : () => _changeStatus(status),
              ),
            ),
        ],
      ),
    );
  }
}

class EmployerPaymentHistoryScreen extends StatelessWidget {
  final String uid;
  const EmployerPaymentHistoryScreen({super.key, required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment history')),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: EmployerService().watchPayments(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StatePanel(
            icon: Icons.wifi_off,
            title: 'Could not load payments',
            detail: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const _StatePanel(
            icon: Icons.receipt_long_outlined,
            title: 'No payments yet',
            detail: 'Your plan purchases will appear here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final amount =
                (order['amountPaise'] is num
                    ? order['amountPaise'] as num
                    : 0) /
                100;
            final tax = ((order['taxPaise'] as num?) ?? 0) / 100;
            return Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                title: Text('${order['planName'] ?? 'Hiring plan'} · ₹${amount.toStringAsFixed(2)}'),
                subtitle: Text('GST ₹${tax.toStringAsFixed(2)} · Order ${order['id']}'),
                trailing: _StatusPill(
                  text: order['status'] == 'paid' ? 'Paid' :
                      order['status'] == 'refunded' ? 'Refunded' : 'Pending',
                  positive: order['status'] == 'paid',
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary,
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.35),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final String text;
  final bool positive;
  const _StatusPill({required this.text, required this.positive});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: positive ? const Color(0xFFE9F9EF) : const Color(0xFFFFF3E3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: positive ? AppTheme.success : const Color(0xFF9C6100),
      ),
    ),
  );
}
