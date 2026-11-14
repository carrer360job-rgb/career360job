import 'package:flutter/material.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerJobFormScreen extends StatefulWidget {
  final EmployerProfile profile;
  final JobModel? existingJob;
  final VoidCallback onPlanNeeded;
  const EmployerJobFormScreen({super.key, required this.profile,
    required this.existingJob, required this.onPlanNeeded});

  @override State<EmployerJobFormScreen> createState() => _EmployerJobFormScreenState();
}

class _EmployerJobFormScreenState extends State<EmployerJobFormScreen> {
  final _form = GlobalKey<FormState>();
  final _api = EmployerApiService();
  late final _title = TextEditingController(text: widget.existingJob?.title ?? '');
  late final _description = TextEditingController(text: widget.existingJob?.description ?? '');
  late final _salary = TextEditingController(text: widget.existingJob?.salaryText ?? '');
  late final _district = TextEditingController(
    text: widget.existingJob?.locationCity ?? widget.profile.district);
  late final _vacancies = TextEditingController(
    text: '${widget.existingJob?.vacanciesCount ?? 1}');
  late final _contactName = TextEditingController(
    text: widget.existingJob?.contactName ?? widget.profile.contactName);
  late final _phone = TextEditingController(
    text: widget.existingJob?.phone ?? widget.profile.phone);
  late final _whatsappNumber = TextEditingController(
    text: widget.existingJob?.whatsappNumber ??
        (widget.profile.whatsappPhone.isNotEmpty
            ? widget.profile.whatsappPhone
            : widget.profile.phone));
  late final _email = TextEditingController(
    text: widget.existingJob?.email ?? widget.profile.email);
  String _category = 'IT & Software';
  String _workMode = 'On-site';
  bool _busy = false;
  late bool _isStatewide;

  static const categories = ['IT & Software', 'Manufacturing', 'Sales',
    'Marketing', 'Finance', 'Healthcare', 'Education', 'Design',
    'Customer Support', 'Logistics', 'Hospitality', 'Other'];
  static const workModes = ['On-site', 'Hybrid', 'Remote'];

  @override void initState() {
    super.initState();
    if (categories.contains(widget.existingJob?.category)) _category = widget.existingJob!.category;
    final existingMode = widget.existingJob?.workMode;
    if (existingMode != null && workModes.any((value) => value.toLowerCase() == existingMode.toLowerCase())) {
      _workMode = workModes.firstWhere((value) => value.toLowerCase() == existingMode.toLowerCase());
    }
    _isStatewide = widget.existingJob?.isStatewide ??
        (widget.profile.canPostStatewide && widget.existingJob == null);
    if (_isStatewide && _district.text.trim().isEmpty) {
      _district.text = 'All Tamil Nadu';
    }
  }

  @override void dispose() {
    for (final c in [_title, _description, _salary, _district, _vacancies, _contactName, _phone, _whatsappNumber, _email]) { c.dispose(); }
    super.dispose();
  }

  String? _required(String? value, int min) => (value ?? '').trim().length < min
      ? 'Enter at least $min characters' : null;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!widget.profile.isApproved) {
      _message('Your company must be approved before publishing a job.');
      return;
    }
    if (widget.existingJob == null && !widget.profile.hasActiveCredits) {
      _message('Choose a posting plan to publish this job.');
      Navigator.pop(context);
      widget.onPlanNeeded();
      return;
    }
    setState(() => _busy = true);
    final isStatewide = _isStatewide;
    final isFeatured = widget.profile.isFeaturedPlan || widget.profile.isElitePlan;
    final districtValue = isStatewide ? 'All Tamil Nadu' : _district.text.trim();
    final fields = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'salaryText': _salary.text.trim(),
      'district': districtValue,
      'category': _category,
      'workMode': _workMode,
      'vacanciesCount': int.parse(_vacancies.text.trim()),
      'contactName': _contactName.text.trim(),
      'phone': _phone.text.trim(),
      'whatsappNumber': _whatsappNumber.text.trim(),
      'email': _email.text.trim(),
      'isStatewide': isStatewide,
      'isFeatured': isFeatured,
      'planTier': widget.profile.planTier,
      'planName': widget.profile.activePlanName,
    };
    try {
      if (widget.existingJob == null) {
        await _api.publishJob(fields);
      } else {
        await _api.editJob(widget.existingJob!.id, fields);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        widget.existingJob == null ? 'Job published.' : 'Job updated.')));
    } catch (error) { _message(error.toString().replaceFirst('Bad state: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text)));

  @override Widget build(BuildContext context) {
    final editing = widget.existingJob != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit job' : 'Post a job')),
      body: Form(key: _form, child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32), children: [
          _planBanner(widget.profile),
          const Text('Role details', style: TextStyle(fontSize: 21,
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 5),
          const Text('Write clearly so candidates know what to expect.',
            style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 20),
          _input('Job title', _title, min: 3, max: 100),
          Padding(padding: const EdgeInsets.only(bottom: 14), child: DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _category = v ?? _category))),
          Padding(padding: const EdgeInsets.only(bottom: 14), child: DropdownButtonFormField<String>(
            initialValue: _workMode,
            decoration: const InputDecoration(labelText: 'Work mode', border: OutlineInputBorder()),
            items: workModes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _workMode = v ?? _workMode))),
          if (widget.profile.canPostStatewide) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, color: Color(0xFF7C3AED), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Reach all Tamil Nadu districts',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF4C1D95),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Candidates across Tamil Nadu can discover this job.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6D28D9)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isStatewide,
                    activeThumbColor: const Color(0xFF7C3AED),
                    onChanged: (val) {
                      setState(() {
                        _isStatewide = val;
                        if (val) {
                          _district.text = 'All Tamil Nadu';
                        } else {
                          _district.text = widget.profile.district;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          if (!_isStatewide) ...[
            _input('District / work location', _district, min: 2, max: 80),
            if (!widget.profile.canPostStatewide)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: widget.onPlanNeeded,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.workspace_premium_outlined, size: 18, color: Color(0xFF7C3AED)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Want statewide reach (39 districts)? Upgrade to Elite Plan',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                controller: _district,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Work Location',
                  prefixIcon: const Icon(Icons.language_rounded, color: Color(0xFF7C3AED)),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  helperText: 'Job will be promoted across all 39 Tamil Nadu districts',
                  helperStyle: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
          _input('Salary (for example ₹20,000–₹30,000 / month)', _salary, min: 3, max: 80),
          _input('Openings', _vacancies, min: 1, max: 3,
            keyboard: TextInputType.number,
            validator: (v) {
              final count = int.tryParse((v ?? '').trim());
              return count == null || count < 1 || count > 999 ? 'Enter 1–999 openings' : null;
            }),
          _input('Description, responsibilities and requirements', _description,
            min: 30, max: 5000, lines: 9),
          const SizedBox(height: 14),
          const Text('Direct Candidate Connect', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Job seekers will contact you directly via Call, WhatsApp, and Email using these details.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          _input('Recruiter / HR Contact Person', _contactName, min: 2, max: 80),
          _input('Direct Calling Phone Number', _phone, min: 10, max: 15, keyboard: TextInputType.phone),
          _input('WhatsApp Number for Inquiries', _whatsappNumber, min: 10, max: 15, keyboard: TextInputType.phone),
          _input('Hiring Contact Email', _email, min: 5, max: 100, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 6),
          if (!editing) Card(color: AppTheme.primaryLight,
            child: Padding(padding: const EdgeInsets.all(14), child: Text(
              'Publishing uses 1 of your ${widget.profile.postingCredits} posting credit(s). The listing stays live for ${widget.profile.listingDays} days unless you close it earlier.',
              style: const TextStyle(height: 1.4)))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _submit,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(_busy ? 'Saving…' : editing ? 'Save changes' : 'Publish job'))),
        ],
      )),
    );
  }

  Widget _planBanner(EmployerProfile profile) {
    final isElite = profile.isElitePlan;
    final isFeatured = profile.isFeaturedPlan;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isElite
            ? const Color(0xFF2E1065)
            : isFeatured
                ? const Color(0xFF451A03)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isElite
              ? const Color(0xFF8B5CF6)
              : isFeatured
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE2E8F0),
          width: (isElite || isFeatured) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isElite
                    ? Icons.workspace_premium_rounded
                    : isFeatured
                        ? Icons.star_rounded
                        : Icons.card_membership_rounded,
                color: (isElite || isFeatured) ? Colors.amberAccent : AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.activePlanName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: (isElite || isFeatured) ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isElite || isFeatured)
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.planBadgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: (isElite || isFeatured) ? Colors.white : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isElite
                ? '👑 Elite Statewide Plan: 30 days validity, broadcasted to candidates across all 39 Tamil Nadu districts with Featured Priority badge.'
                : isFeatured
                    ? '⭐ Featured Priority Plan: 30 days validity with gold Featured badge and prioritized ranking.'
                    : profile.isStandardPlan
                        ? '✓ Standard Plan: 15 days validity in your designated district.'
                        : '✓ Free Starter Plan: 7 days validity in your local district.',
            style: TextStyle(
              fontSize: 13,
              color: (isElite || isFeatured) ? const Color(0xFFE2E8F0) : AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: (isElite || isFeatured) ? Colors.greenAccent : AppTheme.success,
              ),
              const SizedBox(width: 6),
              Text(
                '${profile.postingCredits} credit${profile.postingCredits == 1 ? '' : 's'} available · ${profile.listingDays} days live duration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (isElite || isFeatured) ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _input(String label, TextEditingController controller, {
    required int min, required int max, int lines = 1,
    TextInputType? keyboard, String? Function(String?)? validator,
  }) => Padding(padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(controller: controller, maxLines: lines, maxLength: max,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(),
        alignLabelWithHint: lines > 1),
      validator: validator ?? (v) => _required(v, min)));
}
