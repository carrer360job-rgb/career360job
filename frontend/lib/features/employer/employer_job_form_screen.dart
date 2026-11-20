import 'package:flutter/material.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/platform_content_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';
import '../../data/models/job_model.dart';

class EmployerJobFormScreen extends StatefulWidget {
  final EmployerProfile profile;
  final JobModel? existingJob;
  final VoidCallback onPlanNeeded;

  const EmployerJobFormScreen({
    super.key,
    required this.profile,
    required this.existingJob,
    required this.onPlanNeeded,
  });

  @override
  State<EmployerJobFormScreen> createState() => _EmployerJobFormScreenState();
}

class _EmployerJobFormScreenState extends State<EmployerJobFormScreen> {
  final _form = GlobalKey<FormState>();
  final _api = EmployerApiService();

  late final _title = TextEditingController(text: widget.existingJob?.title ?? '');
  late final _description = TextEditingController(text: widget.existingJob?.description ?? '');
  late final _salary = TextEditingController(text: widget.existingJob?.salaryText ?? '');
  late final _district = TextEditingController(
    text: widget.existingJob?.locationCity ?? widget.profile.district,
  );
  late final _vacancies = TextEditingController(
    text: '${widget.existingJob?.vacanciesCount ?? 1}',
  );
  late final _contactName = TextEditingController(
    text: widget.existingJob?.contactName ?? widget.profile.contactName,
  );
  late final _phone = TextEditingController(
    text: widget.existingJob?.phone ?? widget.profile.phone,
  );
  late final _whatsappNumber = TextEditingController(
    text: widget.existingJob?.whatsappNumber ??
        (widget.profile.whatsappPhone.isNotEmpty
            ? widget.profile.whatsappPhone
            : widget.profile.phone),
  );
  late final _email = TextEditingController(
    text: widget.existingJob?.email ?? widget.profile.email,
  );

  String _category = 'Information Technology & Services';
  String _workMode = 'On-site';
  bool _busy = false;
  late bool _isStatewide;
  bool _sameAsCallingNumber = true;
  final List<String> _categories = List.from(categories);

  static const categories = [
    'Information Technology & Services',
    'Manufacturing & Production',
    'Healthcare & Pharmaceuticals',
    'Education & EdTech',
    'Retail & E-commerce',
    'Banking, Financial Services & Insurance (BFSI)',
    'Logistics & Supply Chain',
    'Hospitality, Travel & Tourism',
    'Real Estate & Construction',
    'Media, Advertising & Entertainment',
    'Automobile & Transportation',
    'Agriculture & Food Processing',
    'Telecommunications',
    'Non-Profit & NGO',
    'Other Industry',
  ];

  static const workModes = ['On-site', 'Hybrid', 'Remote'];

  static const salaryPresets = [
    '₹15,000 – ₹25,000 / month',
    '₹25,000 – ₹40,000 / month',
    '₹40,000 – ₹60,000 / month',
    '₹6 – 10 LPA',
    '₹10 – 18 LPA',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingJob?.category.trim().isNotEmpty == true) {
      _category = widget.existingJob!.category.trim();
    }
    Future.microtask(_loadManagedCategories);

    final existingMode = widget.existingJob?.workMode;
    if (existingMode != null &&
        workModes.any((v) => v.toLowerCase() == existingMode.toLowerCase())) {
      _workMode = workModes.firstWhere(
        (v) => v.toLowerCase() == existingMode.toLowerCase(),
      );
    }

    _isStatewide = widget.existingJob?.isStatewide ??
        (widget.profile.canPostStatewide && widget.existingJob == null);
    if (_isStatewide && _district.text.trim().isEmpty) {
      _district.text = 'All Tamil Nadu';
    }

    _sameAsCallingNumber = _whatsappNumber.text.trim().isEmpty ||
        _whatsappNumber.text.trim() == _phone.text.trim();
    if (_sameAsCallingNumber && _phone.text.trim().isNotEmpty) {
      _whatsappNumber.text = _phone.text.trim();
    }
  }

  Future<void> _loadManagedCategories() async {
    try {
      final items = await PlatformContentService().list('category');
      final managed = items
          .map((item) => item['title'])
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      if (!mounted || managed.isEmpty) return;
      setState(() {
        for (final m in managed) {
          if (!_categories.contains(m)) _categories.add(m);
        }
      });
    } catch (_) {
      // Keep bundled category list when offline.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _salary,
      _district,
      _vacancies,
      _contactName,
      _phone,
      _whatsappNumber,
      _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value, int min) =>
      (value ?? '').trim().length < min ? 'Enter at least $min characters' : null;

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
    final whatsappValue = _sameAsCallingNumber ? _phone.text.trim() : _whatsappNumber.text.trim();
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
      'whatsappNumber': whatsappValue,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingJob == null ? 'Job published successfully.' : 'Job updated successfully.',
          ),
        ),
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  // --- Searchable Modal Bottom Sheet (Exact Match to Company Details) ---
  Future<String?> _openSearchableBottomSheet({
    required String title,
    required List<String> options,
    String? selectedValue,
    IconData? itemIcon,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var searchQuery = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = options
                .where(
                  (opt) => opt.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Solid Emerald Header Bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),

                    // Search Input Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: TextField(
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Search $title...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                    ),

                    // Custom entry card if typed and no exact match
                    if (searchQuery.trim().isNotEmpty &&
                        !filtered.any(
                          (it) => it.toLowerCase() == searchQuery.trim().toLowerCase(),
                        ))
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryLightBorder),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary,
                            child: Icon(Icons.add_rounded, color: Colors.white, size: 16),
                          ),
                          title: Text(
                            'Use "${searchQuery.trim()}"',
                            style: const TextStyle(
                              color: AppTheme.primaryDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to select this custom item',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                          onTap: () {
                            Navigator.pop(sheetContext, searchQuery.trim());
                          },
                        ),
                      ),

                    // Options List
                    Expanded(
                      child: filtered.isEmpty
                          ? (searchQuery.trim().isNotEmpty
                              ? const SizedBox.shrink()
                              : const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                    child: Text(
                                      'No matching items found',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ))
                          : ListView.separated(
                              controller: scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final isSelected = item == selectedValue;
                                return ListTile(
                                  dense: true,
                                  tileColor: isSelected
                                      ? AppTheme.primaryLight
                                      : Colors.transparent,
                                  leading: Icon(
                                    itemIcon ?? Icons.business_outlined,
                                    size: 20,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : const Color(0xFF64748B),
                                  ),
                                  title: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppTheme.primaryDark
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: AppTheme.primary,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () => Navigator.pop(sheetContext, item),
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingJob != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing ? 'Edit Job' : 'Post a Job',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              editing ? 'Update job details & requirements' : 'Create a new candidate vacancy',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            // Plan Quota Banner
            _planBanner(widget.profile),

            // Card 1: Role & Category
            _sectionCard(
              title: '1. Role & Category',
              icon: Icons.work_outline_rounded,
              subtitle: 'Core information candidates see in their feed',
              children: [
                _buildFieldLabel('Job Title *'),
                _input(
                  '',
                  _title,
                  min: 3,
                  max: 100,
                  hint: 'e.g. Senior Flutter Developer',
                  prefixIcon: Icons.badge_outlined,
                ),
                _buildWorkModeSelector(),
                const SizedBox(height: 14),
                _buildIndustrySelector(),
              ],
            ),

            // Card 2: Location & Reach
            _sectionCard(
              title: '2. Location & Candidate Reach',
              icon: Icons.location_on_outlined,
              subtitle: 'Where this position is stationed',
              children: [
                if (widget.profile.canPostStatewide) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryLightBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.public_rounded, color: AppTheme.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Statewide Tamil Nadu Promotion',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Promoted to candidates across all 39 TN districts',
                                style: TextStyle(fontSize: 11, color: AppTheme.primaryDark),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isStatewide,
                          activeTrackColor: AppTheme.primary,
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            setState(() {
                              _isStatewide = val;
                              _district.text = val ? 'All Tamil Nadu' : widget.profile.district;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (!_isStatewide) ...[
                  _buildFieldLabel('Work Location / District *'),
                  _buildDistrictSelector(),
                  if (!widget.profile.canPostStatewide) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: widget.onPlanNeeded,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.workspace_premium_outlined, size: 18, color: AppTheme.primary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Want statewide reach (39 districts)? Upgrade plan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  _buildFieldLabel('Promoted Work Location'),
                  TextFormField(
                    controller: _district,
                    enabled: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.language_rounded, color: AppTheme.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      helperText: 'Promoted across all 39 Tamil Nadu districts',
                      helperStyle: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),

            // Card 3: Compensation & Openings
            _sectionCard(
              title: '3. Compensation & Openings',
              icon: Icons.payments_outlined,
              subtitle: 'Clear salary ranges boost qualified applicant response',
              children: [
                _buildFieldLabel('Monthly Salary / CTC Range *'),
                _input(
                  '',
                  _salary,
                  min: 3,
                  max: 80,
                  hint: 'e.g. ₹25,000 – ₹35,000 / month or ₹8 – 12 LPA',
                  prefixIcon: Icons.currency_rupee_rounded,
                ),
                _buildSalaryChips(),
                const SizedBox(height: 14),
                _buildFieldLabel('Number of Vacancies *'),
                _buildVacanciesField(),
              ],
            ),

            // Card 4: Description & Requirements
            _sectionCard(
              title: '4. Job Description & Requirements',
              icon: Icons.description_outlined,
              subtitle: 'Minimum 30 characters explaining roles and responsibilities',
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFieldLabel('Roles, Responsibilities & Skills *'),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _insertDescriptionTemplate,
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 14, color: AppTheme.primary),
                      label: const Text(
                        'Insert Template',
                        style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                _input(
                  '',
                  _description,
                  min: 30,
                  max: 5000,
                  lines: 7,
                  hint: '• Describe key daily responsibilities\n• Required skills & qualifications\n• Work timings, benefits, and incentives',
                ),
              ],
            ),

            // Card 5: Direct Candidate Connect
            _sectionCard(
              title: '5. Direct Recruiter Contact',
              icon: Icons.contact_phone_outlined,
              subtitle: 'Job seekers apply and communicate directly with your hiring team',
              children: [
                _buildFieldLabel('Hiring / HR Contact Person *'),
                _input(
                  '',
                  _contactName,
                  min: 2,
                  max: 80,
                  hint: 'Full name',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                _buildFieldLabel('Direct Calling Phone Number *'),
                _input(
                  '',
                  _phone,
                  min: 10,
                  max: 15,
                  keyboard: TextInputType.phone,
                  hint: '10-digit mobile number',
                  prefixIcon: Icons.phone_outlined,
                  onChanged: (val) {
                    if (_sameAsCallingNumber) {
                      setState(() => _whatsappNumber.text = val);
                    }
                  },
                ),
                _buildFieldLabel('WhatsApp Contact *'),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildCustomRadioButton(
                      label: 'Same as mobile',
                      isSelected: _sameAsCallingNumber,
                      onTap: () {
                        setState(() {
                          _sameAsCallingNumber = true;
                          _whatsappNumber.text = _phone.text.trim();
                        });
                      },
                    ),
                    _buildCustomRadioButton(
                      label: 'Different WhatsApp',
                      isSelected: !_sameAsCallingNumber,
                      onTap: () {
                        setState(() {
                          _sameAsCallingNumber = false;
                          if (_whatsappNumber.text == _phone.text.trim()) {
                            _whatsappNumber.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildFieldLabel('WhatsApp Number for Inquiries *'),
                _input(
                  '',
                  _whatsappNumber,
                  min: 10,
                  max: 15,
                  keyboard: TextInputType.phone,
                  hint: _sameAsCallingNumber
                      ? 'Auto-synced with mobile number'
                      : 'Enter 10-digit WhatsApp number',
                  prefixIcon: Icons.chat_outlined,
                  readOnly: _sameAsCallingNumber,
                  fillColor: _sameAsCallingNumber ? const Color(0xFFF8FAFC) : Colors.white,
                  onTap: _sameAsCallingNumber
                      ? () {
                          setState(() {
                            _sameAsCallingNumber = false;
                            if (_whatsappNumber.text == _phone.text.trim()) {
                              _whatsappNumber.clear();
                            }
                          });
                        }
                      : null,
                  suffixWidget: _sameAsCallingNumber
                      ? Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 13, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Synced',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        )
                      : (_whatsappNumber.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () => setState(() => _whatsappNumber.clear()),
                            )
                          : null),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (_sameAsCallingNumber) {
                      return RegExp(r'^\d{10,}$').hasMatch(_phone.text.trim())
                          ? null
                          : 'Enter valid calling phone number above';
                    }
                    return RegExp(r'^\d{10,}$').hasMatch(val)
                        ? null
                        : 'Enter valid 10-digit WhatsApp number';
                  },
                ),
                _buildFieldLabel('Hiring Contact Email *'),
                _input(
                  '',
                  _email,
                  min: 5,
                  max: 100,
                  keyboard: TextInputType.emailAddress,
                  hint: 'hr@company.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!editing) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Uses 1 credit (${widget.profile.postingCredits} left) · Live for ${widget.profile.listingDays} days',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                editing ? Icons.check_circle_rounded : Icons.rocket_launch_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                editing ? 'Save Changes' : 'Publish Job Listing',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper: Field Label ---
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  // --- Helper: Section Card Container ---
  Widget _sectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // --- Work Mode Selector ---
  Widget _buildWorkModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Work Mode *'),
        Row(
          children: workModes.map((mode) {
            final isSelected = _workMode.toLowerCase() == mode.toLowerCase();
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode != workModes.last ? 8 : 0,
                ),
                child: InkWell(
                  onTap: () => setState(() => _workMode = mode),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryLight : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.primary : const Color(0xFFCBD5E1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mode == 'On-site'
                              ? Icons.business_rounded
                              : mode == 'Hybrid'
                                  ? Icons.sync_alt_rounded
                                  : Icons.home_work_rounded,
                          size: 15,
                          color: isSelected ? AppTheme.primaryDark : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mode,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Industry Selector Field Trigger ---
  Widget _buildIndustrySelector() {
    final hasValue = _category.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Industry Category *'),
        InkWell(
          onTap: () async {
            final selected = await _openSearchableBottomSheet(
              title: 'Choose Industry',
              options: _categories,
              selectedValue: _category,
              itemIcon: Icons.business_outlined,
            );
            if (selected != null && mounted) {
              setState(() => _category = selected);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_outlined, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasValue ? _category : 'Select industry category',
                    style: TextStyle(
                      fontSize: 14.5,
                      color: hasValue ? AppTheme.textPrimary : const Color(0xFF94A3B8),
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- District / City Selector ---
  Widget _buildDistrictSelector() {
    final tnDistricts = LocationService.getDistrictsForState('Tamil Nadu');
    final hasValue = _district.text.trim().isNotEmpty;

    return InkWell(
      onTap: () async {
        final selected = await _openSearchableBottomSheet(
          title: 'Choose District / Location',
          options: tnDistricts,
          selectedValue: _district.text.trim(),
          itemIcon: Icons.location_on_outlined,
        );
        if (selected != null && mounted) {
          setState(() => _district.text = selected);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_city_rounded, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? _district.text : 'Select city / district (e.g. Chennai, Coimbatore)',
                style: TextStyle(
                  fontSize: 14.5,
                  color: hasValue ? AppTheme.textPrimary : const Color(0xFF94A3B8),
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  // --- Salary Quick Chips ---
  Widget _buildSalaryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: salaryPresets.map((preset) {
          final isSelected = _salary.text.trim() == preset;
          return Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: InkWell(
              onTap: () => setState(() => _salary.text = preset),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLight : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  preset,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Insert Description Template ---
  void _insertDescriptionTemplate() {
    const template = '''• Key Responsibilities:
  - Lead and execute daily tasks with attention to quality
  - Collaborate with cross-functional teams to meet deadlines
  - Ensure high standards of documentation and deliverables

• Qualifications & Skills Required:
  - Strong fundamental knowledge and problem-solving mindset
  - Relevant domain experience (minimum 1–2 years)
  - Excellent communication and team collaboration skills

• Work Hours, Perks & Benefits:
  - Regular day shifts with standard leave entitlements
  - Performance incentives and professional growth opportunities''';

    if (_description.text.trim().isEmpty) {
      setState(() => _description.text = template);
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insert Template?'),
          content: const Text('This will replace your current description with a structured template outline.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                setState(() => _description.text = template);
                Navigator.pop(ctx);
              },
              child: const Text('Replace'),
            ),
          ],
        ),
      );
    }
  }

  // --- Vacancies Stepper Field ---
  Widget _buildVacanciesField() {
    final count = int.tryParse(_vacancies.text.trim()) ?? 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _vacancies,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 2',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(Icons.group_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (v) {
              final c = int.tryParse((v ?? '').trim());
              return c == null || c < 1 || c > 999 ? 'Enter 1–999 openings' : null;
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 20),
                color: count > 1 ? AppTheme.textPrimary : Colors.grey.shade400,
                onPressed: count > 1
                    ? () => setState(() => _vacancies.text = '${count - 1}')
                    : null,
              ),
              Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 20),
                color: count < 999 ? AppTheme.primary : Colors.grey.shade400,
                onPressed: count < 999
                    ? () => setState(() => _vacancies.text = '${count + 1}')
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Plan Banner ---
  Widget _planBanner(EmployerProfile profile) {
    final isElite = profile.isElitePlan;
    final isFeatured = profile.isFeaturedPlan;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isElite
            ? const Color(0xFF064E3B)
            : isFeatured
                ? const Color(0xFF065F46)
                : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isElite || isFeatured)
              ? const Color(0xFF059669)
              : AppTheme.primaryLightBorder,
          width: 1.5,
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
                color: (isElite || isFeatured) ? const Color(0xFFFDE047) : AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profile.activePlanName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: (isElite || isFeatured) ? Colors.white : AppTheme.primaryDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isElite || isFeatured)
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isElite || isFeatured)
                        ? Colors.transparent
                        : AppTheme.primaryLightBorder,
                  ),
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
          const SizedBox(height: 6),
          Text(
            isElite
                ? '👑 Elite Statewide Plan: Broadcasted to candidates across all 39 Tamil Nadu districts.'
                : isFeatured
                    ? '⭐ Featured Priority Plan: 30 days validity with priority ranking.'
                    : profile.hasActiveCredits
                        ? '${profile.activePlanName}: Valid for ${profile.listingDays} days in ${profile.planReach == 'statewide' ? 'Tamil Nadu' : 'one district'}.'
                        : 'An active posting plan is required to publish a job.',
            style: TextStyle(
              fontSize: 12,
              color: (isElite || isFeatured)
                  ? const Color(0xFFDCFCE7)
                  : AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: (isElite || isFeatured) ? const Color(0xFF4ADE80) : AppTheme.success,
              ),
              const SizedBox(width: 6),
              Text(
                '${profile.postingCredits} credit${profile.postingCredits == 1 ? '' : 's'} available · ${profile.listingDays} days duration',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (isElite || isFeatured) ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Custom Radio Button ---
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
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Input Field ---
  Widget _input(
    String label,
    TextEditingController controller, {
    required int min,
    required int max,
    int lines = 1,
    TextInputType? keyboard,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixWidget,
    bool readOnly = false,
    Color? fillColor,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: lines,
        maxLength: max,
        keyboardType: keyboard,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label.isNotEmpty ? label : null,
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: AppTheme.textSecondary)
              : null,
          suffixIcon: suffixWidget,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          alignLabelWithHint: lines > 1,
          filled: true,
          fillColor: fillColor ?? Colors.white,
        ),
        validator: validator ?? (v) => _required(v, min),
      ),
    );
  }
}
