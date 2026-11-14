import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/responsive/responsive_layout.dart';
import '../../core/services/employer_service.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/bouncy_button.dart';

/// Company Registration — 3-Screen UI/UX Flow
/// Replicates the exact visual patterns from the Candidate Personal Info screen:
/// - Clean white canvas with no redundant card-in-card wrapping
/// - Centered title in deep navy with back arrow
/// - Floating circular step numbers (1 ── 2 ── 3) directly under title
/// - Bold labels above outlined rounded inputs with muted outline icons
/// - Radio selector rows for WhatsApp Contact
/// - Blue "Detect Location" button + "─── OR ───" divider + Outlined Dropdown pickers
/// - Bottom bar: "< Back" on left, blue "Continue →" pill button on right
class EmployerRegistrationScreen extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onSubmissionStarted;
  final VoidCallback onSubmissionFailed;
  final VoidCallback onFinished;

  const EmployerRegistrationScreen({
    super.key,
    required this.onSignOut,
    required this.onSubmissionStarted,
    required this.onSubmissionFailed,
    required this.onFinished,
  });

  @override
  State<EmployerRegistrationScreen> createState() =>
      _EmployerRegistrationScreenState();
}

class _EmployerRegistrationScreenState
    extends State<EmployerRegistrationScreen> {
  // Theme Design Tokens from Candidate UI Screenshot
  static const Color _primaryBlue = Color(0xFF155EEF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);
  static const Color _textMuted = Color(0xFF94A3B8);
  static const Color _inputBorder = Color(0xFFD0D5DD);
  static const Color _stepInactive = Color(0xFFE2E8F0);
  static const Color _successGreen = Color(0xFF16A34A);
  static const Color _successLight = Color(0xFFDCFCE7);
  static const Color _errorRed = Color(0xFFDC2626);

  // Dropdown Options
  static const _designations = [
    'Owner / Founder',
    'HR / Recruiter',
    'Hiring Manager',
    'Director / CXO',
    'Branch Admin',
  ];

  static const _industries = [
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

  static const _companySizes = [
    '1–5',
    '6–10',
    '11–50',
    '51–100',
    '101–500',
    'Above 500',
  ];

  static const _stepTitles = [
    'Recruiter Info',
    'Company Details',
    'Location Details',
  ];

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _service = EmployerService();
  final _locationService = LocationService();

  // Screen 1: Recruiter Details
  final _fullNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappPhoneController = TextEditingController();
  bool _sameAsCallingNumber = true;

  // Screen 2: Company Details
  final _companyNameController = TextEditingController();
  final _industryController = TextEditingController();
  final _companySizeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();

  // Screen 3: Location Details
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();

  int _step = 0; // 0: Recruiter, 1: Company, 2: Location
  bool _submitting = false;
  bool _detectingLocation = false;

  @override
  void initState() {
    super.initState();

    _phoneController.addListener(() {
      if (_sameAsCallingNumber) {
        _whatsappPhoneController.text = _phoneController.text;
      }
    });

    for (final c in [
      _fullNameController,
      _designationController,
      _emailController,
      _phoneController,
      _whatsappPhoneController,
      _companyNameController,
      _industryController,
      _companySizeController,
      _addressController,
      _stateController,
      _districtController,
      _pincodeController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fullNameController.dispose();
    _designationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappPhoneController.dispose();
    _companyNameController.dispose();
    _industryController.dispose();
    _companySizeController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  bool _isStepValid() {
    if (_step == 0) {
      final name = _fullNameController.text.trim();
      final desig = _designationController.text.trim();
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final whatsapp = _sameAsCallingNumber
          ? phone
          : _whatsappPhoneController.text.trim();
      return name.length >= 2 &&
          desig.isNotEmpty &&
          email.contains('@') &&
          RegExp(r'^\d{10}$').hasMatch(phone) &&
          RegExp(r'^\d{10}$').hasMatch(whatsapp);
    } else if (_step == 1) {
      final compName = _companyNameController.text.trim();
      final ind = _industryController.text.trim();
      final size = _companySizeController.text.trim();
      return compName.length >= 3 && ind.isNotEmpty && size.isNotEmpty;
    } else {
      final addr = _addressController.text.trim();
      final st = _stateController.text.trim();
      final dist = _districtController.text.trim();
      final pin = _pincodeController.text.trim();
      return addr.length >= 5 &&
          st.isNotEmpty &&
          dist.isNotEmpty &&
          RegExp(r'^\d{6}$').hasMatch(pin);
    }
  }

  void _previous() {
    if (_submitting) return;
    if (_step == 0) {
      widget.onSignOut();
    } else {
      setState(() => _step--);
      _scrollToTop();
    }
  }

  void _next() {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    if (_step < 2) {
      setState(() => _step++);
      _scrollToTop();
    } else {
      _submit();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _submit() async {
    widget.onSubmissionStarted();
    setState(() => _submitting = true);
    try {
      final phone = _phoneController.text.trim();
      final whatsapp = _sameAsCallingNumber
          ? phone
          : _whatsappPhoneController.text.trim();

      await _service.register({
        'contactName': _fullNameController.text.trim(),
        'designation': _designationController.text.trim(),
        'companyName': _companyNameController.text.trim(),
        'industry': _industryController.text.trim(),
        'companySize': _companySizeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phone': phone,
        'whatsappPhone': whatsapp,
        'whatsappSameAsPhone': _sameAsCallingNumber,
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'city': '',
        'state': _stateController.text.trim(),
        'district': _districtController.text.trim(),
        'postalCode': _pincodeController.text.trim(),
        'registrationNumber': '',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _successGreen,
            behavior: SnackBarBehavior.floating,
            content: Text('Company details submitted for review.'),
          ),
        );
        widget.onFinished();
      }
    } catch (error) {
      widget.onSubmissionFailed();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _errorRed,
            content: Text(
              'Could not complete registration: ${error.toString().replaceFirst('Bad state: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
                  (opt) =>
                      opt.toLowerCase().contains(searchQuery.toLowerCase()),
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
                    // Solid Blue Header Bar (Matching Job Seeker screenshot)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: _primaryBlue,
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
                                fontSize: 16.5,
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
                            color: _textMuted,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _textSecondary,
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
                              color: _primaryBlue,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                    ),

                    // Custom entry card if typed and no exact match (Exact match to Job Seeker screenshot)
                    if (searchQuery.trim().isNotEmpty &&
                        !filtered.any(
                          (it) =>
                              it.toLowerCase() ==
                              searchQuery.trim().toLowerCase(),
                        ))
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: _primaryBlue,
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            'Use "${searchQuery.trim()}"',
                            style: const TextStyle(
                              color: _primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Tap to select this custom item',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
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
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 32,
                                      ),
                                      child: Text(
                                        'Type above to add and use a custom location',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: _textSecondary,
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
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFF1F5F9),
                                  ),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final isSelected = item == selectedValue;
                                return ListTile(
                                  dense: true,
                                  tileColor: isSelected
                                      ? const Color(0xFFEFF8FF)
                                      : Colors.transparent,
                                  leading: Icon(
                                    itemIcon ?? Icons.location_on_outlined,
                                    size: 20,
                                    color: isSelected
                                        ? _primaryBlue
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
                                          ? _primaryBlue
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: _primaryBlue,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () =>
                                      Navigator.pop(sheetContext, item),
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

  Future<void> _detectLocation() async {
    if (_detectingLocation) return;
    setState(() => _detectingLocation = true);
    try {
      final location = await _locationService.detectCurrentLocation();
      if (!mounted) return;
      if (location == null ||
          location.state.isEmpty ||
          location.district.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _textDark,
            content: Text(
              'Location coordinates unavailable. Please select your address manually.',
            ),
          ),
        );
        return;
      }

      final matchedState = LocationService.indianStates.where(
        (s) => s.toLowerCase() == location.state.toLowerCase(),
      );

      setState(() {
        _stateController.text = matchedState.isEmpty
            ? location.state
            : matchedState.first;
        _districtController.text = location.district;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _successGreen,
          content: Text(
            'Location auto-detected: ${location.district}, ${location.state}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: _textDark,
            content: Text(
              'Could not auto-detect location. Please select manually.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: _step == 0 ? 'Sign out' : 'Back',
          onPressed: _submitting ? null : _previous,
          icon: const Icon(Icons.arrow_back, color: _textDark),
        ),
        title: Text(
          _stepTitles[_step],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : widget.onSignOut,
            child: const Text(
              'Sign out',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 600 : 440),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Step Progress Indicator (Matching Candidate Screenshot)
                _buildStepProgressIndicator(),
                const SizedBox(height: 16),

                // Form Content in Animated Switcher
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Form(
                      key: _formKey,
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
                          key: ValueKey(_step),
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Action Bar (Matching Candidate Screenshot)
                _buildBottomActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Step Progress Indicator: Exactly like Candidate Screenshot ---
  Widget _buildStepProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final stepNum = index + 1;
        final bool isActive = _step == index;
        final bool isPast = _step > index;

        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? _primaryBlue
                    : isPast
                    ? _primaryBlue
                    : _stepInactive,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isPast
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$stepNum',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : _textSecondary,
                      ),
                    ),
            ),
            if (index < 2)
              Container(
                width: 36,
                height: 2,
                color: isPast ? _primaryBlue : _stepInactive,
              ),
          ],
        );
      }),
    );
  }

  // --- Step Router ---
  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildStep1Recruiter();
      case 1:
        return _buildStep2Company();
      case 2:
      default:
        return _buildStep3Location();
    }
  }

  // =========================================================================
  // STEP 1: RECRUITER INFO
  // =========================================================================
  Widget _buildStep1Recruiter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name*
        _buildFieldLabel('Name*'),
        _buildTextInput(
          controller: _fullNameController,
          hintText: 'Enter your full name',
          prefixIcon: Icons.person_outline,
          validator: (v) => (v == null || v.trim().length < 2)
              ? 'Enter at least 2 characters'
              : null,
        ),
        const SizedBox(height: 16),

        // Designation / Role*
        _buildFieldLabel('Designation / Role*'),
        _buildDropdownSelector(
          value: _designationController.text,
          hintText: 'Select your role',
          prefixIcon: Icons.work_outline,
          onTap: () async {
            final selected = await _openSearchableBottomSheet(
              title: 'Choose Designation / Role',
              options: _designations,
              selectedValue: _designationController.text,
              itemIcon: Icons.work_outline,
            );
            if (selected != null && mounted) {
              setState(() => _designationController.text = selected);
            }
          },
        ),
        const SizedBox(height: 16),

        // Email Address*
        _buildFieldLabel('Email Address*'),
        _buildTextInput(
          controller: _emailController,
          hintText: 'Enter work email address',
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final val = (v ?? '').trim();
            return val.contains('@') && val.contains('.')
                ? null
                : 'Enter a valid email address';
          },
        ),
        const SizedBox(height: 16),

        // Mobile Number*
        _buildFieldLabel('Mobile Number*'),
        _buildTextInput(
          controller: _phoneController,
          hintText: 'Enter 10-digit mobile number',
          prefixWidget: _buildCountryCodePrefix(Icons.phone_android_outlined),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) => RegExp(r'^\d{10}$').hasMatch((v ?? '').trim())
              ? null
              : 'Enter a valid 10-digit mobile number',
        ),
        const SizedBox(height: 16),

        // WhatsApp Contact* (Radio options matching Candidate Screenshot)
        _buildFieldLabel('WhatsApp Contact*'),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildCustomRadioButton(
              label: 'Same as mobile',
              isSelected: _sameAsCallingNumber,
              onTap: () {
                setState(() {
                  _sameAsCallingNumber = true;
                  _whatsappPhoneController.text = _phoneController.text;
                });
              },
            ),
            const SizedBox(width: 20),
            _buildCustomRadioButton(
              label: 'Different WhatsApp',
              isSelected: !_sameAsCallingNumber,
              onTap: () {
                setState(() {
                  _sameAsCallingNumber = false;
                  if (_whatsappPhoneController.text == _phoneController.text) {
                    _whatsappPhoneController.clear();
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // WhatsApp Number* (Always visible)
        _buildFieldLabel('WhatsApp Number*'),
        _buildTextInput(
          controller: _whatsappPhoneController,
          hintText: _sameAsCallingNumber
              ? 'Auto-synced with mobile number'
              : 'Enter 10-digit WhatsApp number',
          prefixWidget: _buildCountryCodePrefix(Icons.chat_bubble_outline),
          readOnly: _sameAsCallingNumber,
          fillColor: _sameAsCallingNumber
              ? const Color(0xFFF8FAFC)
              : Colors.white,
          onTap: _sameAsCallingNumber
              ? () {
                  setState(() {
                    _sameAsCallingNumber = false;
                    if (_whatsappPhoneController.text ==
                        _phoneController.text) {
                      _whatsappPhoneController.clear();
                    }
                  });
                }
              : null,
          suffixWidget: _sameAsCallingNumber
              ? Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _successLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF86EFAC),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: Color(0xFF16A34A),
                      ),
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
              : (_whatsappPhoneController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: _textMuted,
                        ),
                        onPressed: () {
                          setState(() => _whatsappPhoneController.clear());
                        },
                      )
                    : null),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            final val = (v ?? '').trim();
            if (_sameAsCallingNumber) {
              return RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim())
                  ? null
                  : 'Enter a valid 10-digit mobile number above';
            }
            return RegExp(r'^\d{10}$').hasMatch(val)
                ? null
                : 'Enter a valid 10-digit WhatsApp number';
          },
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 2: COMPANY DETAILS
  // =========================================================================
  Widget _buildStep2Company() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Name*
        _buildFieldLabel('Company Name*'),
        _buildTextInput(
          controller: _companyNameController,
          hintText: 'Enter registered company name',
          prefixIcon: Icons.business_outlined,
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Enter at least 3 characters'
              : null,
        ),
        const SizedBox(height: 16),

        // Company Type / Industry*
        _buildFieldLabel('Company Type / Industry*'),
        _buildDropdownSelector(
          value: _industryController.text,
          hintText: 'Select industry sector',
          prefixIcon: Icons.category_outlined,
          onTap: () async {
            final selected = await _openSearchableBottomSheet(
              title: 'Choose Industry',
              options: _industries,
              selectedValue: _industryController.text,
              itemIcon: Icons.business_outlined,
            );
            if (selected != null && mounted) {
              setState(() => _industryController.text = selected);
            }
          },
        ),
        const SizedBox(height: 16),

        // Company Size*
        _buildFieldLabel('Company Size*'),
        _buildDropdownSelector(
          value: _companySizeController.text,
          hintText: 'Select number of employees',
          prefixIcon: Icons.people_outline,
          onTap: () async {
            final selected = await _openSearchableBottomSheet(
              title: 'Choose Company Size',
              options: _companySizes,
              selectedValue: _companySizeController.text,
              itemIcon: Icons.people_outline,
            );
            if (selected != null && mounted) {
              setState(() => _companySizeController.text = selected);
            }
          },
        ),
        const SizedBox(height: 16),

        // Company Description (Multiline)
        _buildFieldLabel('Company Description'),
        _buildTextInput(
          controller: _descriptionController,
          hintText: 'Tell candidates about your company...',
          prefixIcon: Icons.description_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Official Website (Optional)
        _buildFieldLabel('Official Website'),
        _buildTextInput(
          controller: _websiteController,
          hintText: 'https://example.com (optional)',
          prefixIcon: Icons.link,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 3: LOCATION DETAILS (Exact Match to Candidate Screenshot)
  // =========================================================================
  Widget _buildStep3Location() {
    final stateDistricts = LocationService.getDistrictsForState(
      _stateController.text.trim(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Address*
        _buildFieldLabel('Company Address*'),
        _buildTextInput(
          controller: _addressController,
          hintText: 'Building name, street, road, landmark...',
          prefixIcon: Icons.apartment_outlined,
          maxLines: 2,
          validator: (v) => (v == null || v.trim().length < 5)
              ? 'Enter at least 5 characters'
              : null,
        ),
        const SizedBox(height: 18),

        // Your Location* (Blue Button from Screenshot)
        _buildFieldLabel('Your Location*'),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: BouncyButton(
            onPressed: _detectingLocation ? null : _detectLocation,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _detectingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Detect Location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ──────── OR ──────── Divider
        Row(
          children: [
            const Expanded(
              child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Expanded(
              child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // State Dropdown
        _buildDropdownSelector(
          value: _stateController.text,
          hintText: 'Select Your State*',
          prefixIcon: Icons.map_outlined,
          onTap: () async {
            final selected = await _openSearchableBottomSheet(
              title: 'Choose Your State',
              options: LocationService.indianStates,
              selectedValue: _stateController.text,
              itemIcon: Icons.map_outlined,
            );
            if (selected != null && mounted) {
              setState(() {
                if (_stateController.text != selected) {
                  _stateController.text = selected;
                  _districtController.clear();
                }
              });
            }
          },
        ),
        const SizedBox(height: 14),

        // District Dropdown
        _buildDropdownSelector(
          value: _districtController.text,
          hintText: 'Select Your District*',
          prefixIcon: Icons.location_on_outlined,
          onTap: () async {
            if (_stateController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: _textDark,
                  content: Text('Please select your State first'),
                ),
              );
              return;
            }
            final stateName = _stateController.text.trim();
            final selected = await _openSearchableBottomSheet(
              title: stateName.isNotEmpty
                  ? 'Choose District in $stateName'
                  : 'Choose Your District',
              options: stateDistricts,
              selectedValue: _districtController.text,
              itemIcon: Icons.location_on_outlined,
            );
            if (selected != null && mounted) {
              setState(() => _districtController.text = selected);
            }
          },
        ),
        const SizedBox(height: 16),

        // Pincode*
        _buildFieldLabel('Pincode*'),
        _buildTextInput(
          controller: _pincodeController,
          hintText: 'Enter 6-digit pincode',
          prefixIcon: Icons.markunread_mailbox_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
              ? null
              : 'Enter a valid 6-digit postal pincode',
        ),
      ],
    );
  }

  // --- Field Label Generator ---
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _textDark,
        ),
      ),
    );
  }

  // --- Permanent Country Code Prefix (+91 |) ---
  Widget _buildCountryCodePrefix(IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 14),
        Icon(icon, color: _textMuted, size: 20),
        const SizedBox(width: 8),
        const Text(
          '+91',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 18, color: const Color(0xFFCBD5E1)),
        const SizedBox(width: 10),
      ],
    );
  }

  // --- Outlined Text Input Field (Exact Match to Candidate Screenshot) ---
  Widget _buildTextInput({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    Widget? prefixWidget,
    Widget? suffixWidget,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    Color? fillColor,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textDark,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon:
            prefixWidget ??
            (prefixIcon != null
                ? Icon(prefixIcon, color: _textMuted, size: 20)
                : null),
        prefixIconConstraints: prefixWidget != null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        suffixIcon: suffixWidget,
        suffixIconConstraints: suffixWidget != null
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        filled: true,
        fillColor: fillColor ?? Colors.white,
        hintStyle: const TextStyle(fontSize: 14, color: _textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _inputBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1),
        ),
      ),
    );
  }

  // --- Outlined Dropdown Selector (Exact Match to Candidate Screenshot) ---
  Widget _buildDropdownSelector({
    required String value,
    required String hintText,
    required IconData prefixIcon,
    required VoidCallback onTap,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return BouncyButton(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _inputBorder, width: 1),
        ),
        child: Row(
          children: [
            Icon(prefixIcon, color: _textMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? value : hintText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                  color: hasValue ? _textDark : _textMuted,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  // --- Custom Radio Button (Matching Candidate Screenshot) ---
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
                color: isSelected ? _primaryBlue : _textMuted,
                width: 1.8,
              ),
            ),
            alignment: Alignment.center,
            child: isSelected
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _primaryBlue,
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
              color: isSelected ? _textDark : _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Action Bar: "< Back to Role" on left, "Continue →" on right ---
  Widget _buildBottomActionBar() {
    final isStepReady = _isStepValid();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Back Text Button
          TextButton.icon(
            onPressed: _submitting ? null : _previous,
            icon: const Icon(
              Icons.chevron_left,
              color: _textSecondary,
              size: 20,
            ),
            label: Text(
              _step == 0 ? 'Back to Role' : 'Back',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ),

          // Right side: Blue Continue Pill Button
          BouncyButton(
            onPressed: (!isStepReady || _submitting) ? null : _next,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: BoxDecoration(
                color: isStepReady
                    ? _primaryBlue
                    : _primaryBlue.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isStepReady
                    ? [
                        BoxShadow(
                          color: _primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _step == 2 ? 'Register Company ✓' : 'Continue',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (_step < 2) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
