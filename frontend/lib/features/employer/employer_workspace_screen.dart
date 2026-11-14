import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/services/employer_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';
import '../notifications/notification_center_screen.dart';
import 'employer_job_form_screen.dart';
import 'employer_plan_screen.dart';

class EmployerWorkspaceScreen extends StatefulWidget {
  final EmployerProfile profile;
  final VoidCallback onSignOut;

  const EmployerWorkspaceScreen({
    super.key,
    required this.profile,
    required this.onSignOut,
  });

  @override
  State<EmployerWorkspaceScreen> createState() =>
      _EmployerWorkspaceScreenState();
}

class _EmployerWorkspaceScreenState extends State<EmployerWorkspaceScreen> {
  final _service = EmployerService();
  final _api = EmployerApiService();
  late Stream<List<JobModel>> _jobsStream;
  late Stream<List<Map<String, dynamic>>> _applicationsStream;
  Future<Map<String, dynamic>>? _entitlementFuture;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
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
        _subscriptionCard(profile),
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
              ? (profile.status == 'rejected'
                    ? 'Company review needed'
                    : 'Company review in progress')
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
              ? (profile.status == 'rejected'
                    ? 'Your company needs another review before posting jobs.'
                    : 'You can choose a posting plan after your company is approved.')
              : live == 0
              ? 'Publish a job and reach Career360 candidates.'
              : '$live live jobs · $applicants applications',
          style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.35),
        ),
        if (profile.isApproved) ...[
          const SizedBox(height: 17),
          FilledButton.icon(
            onPressed: () => _openJobForm(),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryDark,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Post a job'),
          ),
        ],
        if (profile.isApproved && !profile.hasActiveCredits)
          TextButton(
            onPressed: _openPlans,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('See posting plans →'),
          ),
      ],
    ),
  );

  Widget _subscriptionCard(EmployerProfile profile) {
    final isElite = profile.isElitePlan;
    final isFeatured = profile.isFeaturedPlan;
    final hasCredits = profile.hasActiveCredits;
    final daysLeft = profile.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isElite
              ? const Color(0xFFDDD6FE)
              : isFeatured
              ? const Color(0xFFFED7AA)
              : const Color(0xFFE2E8F0),
          width: (isElite || isFeatured) ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isElite
                        ? const Color(0xFFF5F3FF)
                        : isFeatured
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isElite
                        ? Icons.workspace_premium_rounded
                        : isFeatured
                        ? Icons.star_rounded
                        : Icons.card_membership_rounded,
                    color: isElite
                        ? const Color(0xFF7C3AED)
                        : isFeatured
                        ? const Color(0xFFD97706)
                        : AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.activePlanName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isElite
                            ? 'Broadcast to all 39 Tamil Nadu Districts'
                            : isFeatured
                            ? 'Priority Featured Listing in ${profile.district}'
                            : 'Standard Listing in ${profile.district}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isElite
                        ? const Color(0xFF7C3AED)
                        : isFeatured
                        ? const Color(0xFFF59E0B)
                        : AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    profile.planBadgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: (isElite || isFeatured)
                          ? Colors.white
                          : AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Posting Credits',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasCredits
                            ? '${profile.postingCredits} Available'
                            : '0 Available',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: hasCredits
                              ? AppTheme.textPrimary
                              : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plan Validity',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.hasActiveCredits && daysLeft > 0
                            ? '$daysLeft days left'
                            : (profile.hasActiveCredits
                                  ? '${profile.listingDays} days / post'
                                  : 'Inactive / Expired'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: (profile.hasActiveCredits && daysLeft <= 3)
                              ? const Color(0xFFD97706)
                              : (profile.hasActiveCredits
                                    ? AppTheme.textPrimary
                                    : AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openPlans,
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  hasCredits
                      ? 'Upgrade / Change Plan'
                      : 'Choose a Posting Plan',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
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

  Widget _company() {
    final profile = widget.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      children: [
        const _SectionTitle('Company profile'),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.companyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _StatusPill(
                  text: profile.status == 'rejected'
                      ? 'Needs attention'
                      : 'Verified Company',
                  positive: profile.status != 'rejected',
                ),
                const Divider(height: 26),
                _detail(
                  'Contact',
                  '${profile.contactName} · ${profile.designation}',
                ),
                _detail('Email', profile.email),
                _detail(
                  'Phone',
                  profile.phone.isEmpty ? 'Not provided' : profile.phone,
                ),
                _detail(
                  'WhatsApp',
                  profile.whatsappPhone.isEmpty
                      ? 'Not provided'
                      : profile.whatsappPhone,
                ),
                _detail('Industry', profile.industry),
                _detail('Company size', profile.companySize),
                _detail(
                  'Address',
                  '${profile.address}, ${profile.district}, ${profile.state} ${profile.postalCode}',
                ),
                if (profile.website.isNotEmpty)
                  _detail('Website', profile.website),
                if (profile.registrationNumber.isNotEmpty)
                  _detail('Registration ID', profile.registrationNumber),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EmployerContactEditScreen(profile: profile),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit contact details'),
                ),
              ],
            ),
          ),
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
                    Text(
                      profile.activePlanName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
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
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
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
      content: const Text('This uses one profile unlock from your current plan. The applicant’s contact details and resume will be available until the plan expires.'),
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
              const Text('Contact details and resume are available after a profile unlock.'),
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
          if (_unlocked) OutlinedButton.icon(
            onPressed: _busy || _profile == null || _profile?['resumeFileName'] == null
                ? null
                : () async {
                    try {
                      final url = await _api.resumeUrl('${a['id']}');
                      if (!context.mounted) return;
                      // The signed URL is short lived and is opened by the device's browser.
                      await launchResume(url);
                    } catch (error) {
                      if (context.mounted) _show(error);
                    }
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_profile?['resumeFileName'] == null ? 'No resume available' : 'View resume'),
          ),
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

class EmployerContactEditScreen extends StatefulWidget {
  final EmployerProfile profile;
  const EmployerContactEditScreen({super.key, required this.profile});
  @override
  State<EmployerContactEditScreen> createState() =>
      _EmployerContactEditScreenState();
}

class _EmployerContactEditScreenState extends State<EmployerContactEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    'contactName': TextEditingController(text: widget.profile.contactName),
    'designation': TextEditingController(text: widget.profile.designation),
    'phone': TextEditingController(text: widget.profile.phone),
    'whatsappPhone': TextEditingController(text: widget.profile.whatsappPhone),
    'website': TextEditingController(text: widget.profile.website),
    'address': TextEditingController(text: widget.profile.address),
    'state': TextEditingController(text: widget.profile.state),
    'district': TextEditingController(text: widget.profile.district),
    'postalCode': TextEditingController(text: widget.profile.postalCode),
  };
  bool _busy = false;
  late bool _sameWhatsappAsPhone;
  String _separateWhatsappPhone = '';

  @override
  void initState() {
    super.initState();
    _sameWhatsappAsPhone = widget.profile.whatsappSameAsPhone;
    if (_sameWhatsappAsPhone) {
      _fields['whatsappPhone']!.text = _fields['phone']!.text;
    } else {
      _separateWhatsappPhone = _fields['whatsappPhone']!.text;
    }
    _fields['phone']!.addListener(_syncWhatsappPhone);
    _fields['whatsappPhone']!.addListener(() {
      if (!_sameWhatsappAsPhone) {
        _separateWhatsappPhone = _fields['whatsappPhone']!.text;
      }
    });
  }

  void _syncWhatsappPhone() {
    final phone = _fields['phone']!.text;
    if (_sameWhatsappAsPhone && _fields['whatsappPhone']!.text != phone) {
      _fields['whatsappPhone']!.text = phone;
    }
  }

  void _setSameWhatsappAsPhone(bool same) {
    if (_sameWhatsappAsPhone == same) return;
    setState(() {
      if (same) {
        _separateWhatsappPhone = _fields['whatsappPhone']!.text;
        _sameWhatsappAsPhone = true;
        _syncWhatsappPhone();
      } else {
        _sameWhatsappAsPhone = false;
        _fields['whatsappPhone']!.text = _separateWhatsappPhone;
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit contact details')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          for (final entry in _fields.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                controller: entry.value,
                readOnly: entry.key == 'whatsappPhone' && _sameWhatsappAsPhone,
                keyboardType: ['phone', 'whatsappPhone'].contains(entry.key)
                    ? TextInputType.phone
                    : entry.key == 'postalCode'
                    ? TextInputType.number
                    : null,
                inputFormatters: ['phone', 'whatsappPhone'].contains(entry.key)
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ]
                    : entry.key == 'postalCode'
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ]
                    : null,
                decoration: InputDecoration(
                  labelText: _label(entry.key),
                  prefixText: ['phone', 'whatsappPhone'].contains(entry.key)
                      ? '+91 '
                      : null,
                  filled: entry.key == 'whatsappPhone' && _sameWhatsappAsPhone,
                  fillColor: AppTheme.background,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _validate(entry.key, value),
              ),
            ),
            if (entry.key == 'phone')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _sameWhatsappAsPhone,
                onChanged: (value) => _setSameWhatsappAsPhone(value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Same number for WhatsApp',
                  style: TextStyle(fontSize: 13.5),
                ),
              ),
          ],
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  String _label(String key) => const {
    'contactName': 'Contact name',
    'designation': 'Role',
    'phone': 'Phone',
    'whatsappPhone': 'WhatsApp number',
    'website': 'Website',
    'address': 'Address',
    'state': 'State',
    'district': 'District',
    'postalCode': 'PIN code',
  }[key]!;
  String? _validate(String key, String? value) {
    final text = (value ?? '').trim();
    if (['phone', 'whatsappPhone'].contains(key) &&
        !RegExp(r'^\d{10}$').hasMatch(text)) {
      return 'Enter a 10-digit number';
    }
    if (key == 'postalCode' && !RegExp(r'^\d{6}$').hasMatch(text)) {
      return 'Enter a 6-digit PIN';
    }
    if (key == 'website' &&
        text.isNotEmpty &&
        !(Uri.tryParse(text)?.hasScheme == true &&
            Uri.tryParse(text)?.host.isNotEmpty == true)) {
      return 'Enter a full URL';
    }
    if (!['phone', 'whatsappPhone', 'website'].contains(key) &&
        text.length < 2) {
      return 'This field is required';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await EmployerService().updateContact(widget.profile.uid, {
        ..._fields.map((key, value) => MapEntry(key, value.text.trim())),
        'whatsappSameAsPhone': _sameWhatsappAsPhone,
      });
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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

Future<void> launchResume(Uri uri) async {
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('No app could open this resume.');
  }
}
