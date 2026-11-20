import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/job_model.dart';
import 'job_application_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobModel job;
  final String candidateUid;
  final bool isApplied;
  final bool isSaved;
  final VoidCallback onApply;
  final VoidCallback onToggleSave;
  final VoidCallback onReport;

  const JobDetailScreen({
    super.key,
    required this.job,
    this.candidateUid = '',
    required this.isApplied,
    required this.isSaved,
    required this.onApply,
    required this.onToggleSave,
    required this.onReport,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late bool _isApplied;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isApplied = widget.isApplied;
    _isSaved = widget.isSaved;
  }

  void _handleToggleSave() {
    setState(() => _isSaved = !_isSaved);
    widget.onToggleSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Job saved to bookmarks' : 'Job removed from bookmarks'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleApply() async {
    if (_isApplied || !widget.job.isOpen) return;
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JobApplicationScreen(
          job: widget.job,
          candidateUid: widget.candidateUid,
          onApplySuccess: () {
            widget.onApply();
          },
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() => _isApplied = true);
    }
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not initiate call to $phone')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String phone, String title) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent(
      'Hi, I am interested in the "$title" position on Career360.',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $phone')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email, String title) async {
    final subject = Uri.encodeComponent('Application for $title - Career360');
    final uri = Uri.parse('mailto:$email?subject=$subject');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email client for $email')),
        );
      }
    }
  }

  String _formatPostedAge(DateTime postedAt) {
    final age = DateTime.now().difference(postedAt);
    if (age.isNegative || age.inMinutes < 60) return 'Posted recently';
    if (age.inHours < 24) return 'Posted ${age.inHours}h ago';
    if (age.inDays == 1) return 'Posted yesterday';
    return 'Posted ${age.inDays}d ago';
  }

  Widget _buildCompanyAvatar(String companyName, {double size = 52}) {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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

  Widget _buildBadge(
    IconData icon,
    String label, {
    Color bg = const Color(0xFFF1F5F9),
    Color fg = const Color(0xFF334155),
    bool isBold = false,
  }) {
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
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppTheme.primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF334155),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Job Details',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSaved ? AppTheme.primary : const Color(0xFF64748B),
              size: 24,
            ),
            tooltip: _isSaved ? 'Remove bookmark' : 'Save job',
            onPressed: _handleToggleSave,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company & Job Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCompanyAvatar(job.companyName, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              job.companyName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (job.isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified,
                              size: 15,
                              color: AppTheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatPostedAge(job.postedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Key Highlights Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (job.isFeatured)
                  _buildBadge(
                    Icons.star_rounded,
                    'Featured Opportunity',
                    bg: const Color(0xFFFEF3C7),
                    fg: const Color(0xFF92400E),
                    isBold: true,
                  ),
                if (job.isStatewide)
                  _buildBadge(
                    Icons.public_rounded,
                    'All Tamil Nadu',
                    bg: const Color(0xFFF5F3FF),
                    fg: const Color(0xFF6D28D9),
                    isBold: true,
                  ),
                _buildBadge(
                  Icons.currency_rupee_rounded,
                  job.salaryText,
                  bg: const Color(0xFFDCFCE7),
                  fg: const Color(0xFF15803D),
                  isBold: true,
                ),
                _buildBadge(
                  Icons.location_on_outlined,
                  job.locationCity,
                ),
                _buildBadge(
                  Icons.business_center_outlined,
                  job.workMode,
                ),
                if (job.category.isNotEmpty)
                  _buildBadge(
                    Icons.category_outlined,
                    job.category,
                  ),
                if (job.vacanciesCount > 0)
                  _buildBadge(
                    Icons.people_alt_outlined,
                    '${job.vacanciesCount} Openings',
                  ),
              ],
            ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 20),

            // Job Description Section
            const Text(
              'Job Description',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              job.description.isNotEmpty
                  ? job.description
                  : 'No specific description provided for this position.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF334155),
                height: 1.55,
              ),
            ),

            // Requirements Section
            if (job.requirements.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Requirements & Qualifications',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              ...job.requirements.map(_buildRequirementBullet),
            ],

            // Responsibilities Section
            if (job.responsibilities.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text(
                'Key Responsibilities',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              ...job.responsibilities.map(_buildRequirementBullet),
            ],

            // Direct Recruiter Connect Card
            if ((job.phone ?? '').isNotEmpty ||
                (job.whatsappNumber ?? '').isNotEmpty ||
                (job.email ?? '').isNotEmpty) ...[
              const SizedBox(height: 26),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.quick_contacts_mail_rounded,
                          color: Color(0xFF15803D),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Direct Recruiter Connect',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF14532D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Contact ${job.contactName?.isNotEmpty == true ? job.contactName : "the recruiter"} directly using the channels below:',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF166534),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if ((job.phone ?? '').isNotEmpty) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _makeCall(job.phone!),
                              icon: const Icon(Icons.call, size: 15),
                              label: const Text('Call HR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF15803D),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if ((job.whatsappNumber ?? job.phone ?? '').isNotEmpty) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openWhatsApp(
                                (job.whatsappNumber ?? job.phone)!,
                                job.title,
                              ),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                              label: const Text('WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if ((job.email ?? '').isNotEmpty) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _sendEmail(job.email!, job.title),
                              icon: const Icon(Icons.email_outlined, size: 15),
                              label: const Text('Email'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Free & Verified Protection Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFB45309),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Career360 jobs are 100% free for candidates. Never pay fees for interviews or job offers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Report Job Option
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.onReport,
                icon: const Icon(Icons.flag_outlined, size: 16, color: Color(0xFF64748B)),
                label: const Text(
                  'Report this job',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // Fixed Bottom Navigation CTA Bar
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
            height: 50,
            child: ElevatedButton(
            onPressed: (_isApplied || !job.isOpen) ? null : _handleApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isApplied
                  ? const Color(0xFFDCFCE7)
                  : AppTheme.primary,
              foregroundColor: _isApplied
                  ? AppTheme.success
                  : Colors.white,
              disabledBackgroundColor: _isApplied
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFCBD5E1),
              disabledForegroundColor: _isApplied
                  ? AppTheme.success
                  : const Color(0xFF64748B),
              elevation: _isApplied ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isApplied) ...[
                  const Icon(Icons.check_circle_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Already Applied',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else if (!job.isOpen) ...[
                  const Icon(Icons.lock_clock_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Applications Closed',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Apply for this Job',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
