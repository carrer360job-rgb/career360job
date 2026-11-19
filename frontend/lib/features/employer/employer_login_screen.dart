import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_auth_service.dart';
import '../../core/widgets/bouncy_button.dart';
import '../../core/widgets/searchable_category_picker_sheet.dart';
import '../legal/privacy_policy_screen.dart';

enum EmployerAuthState { signIn, signUp, verifyEmail, forgotPassword }

/// Dedicated Authentication Portal for Employers, Recruiters, and HR Managers.
class EmployerLoginScreen extends StatefulWidget {
  final VoidCallback onBack;

  const EmployerLoginScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<EmployerLoginScreen> createState() => _EmployerLoginScreenState();
}

class _EmployerLoginScreenState extends State<EmployerLoginScreen> {
  final SupabaseAuthService _supabaseAuth = SupabaseAuthService();
  EmployerAuthState _screenState = EmployerAuthState.signIn;
  int _forgotPasswordStep = 1; // 1 = Enter Work Email, 2 = Enter OTP & Set New Password

  // Emerald Growth Design Tokens
  static const Color _emeraldPrimary = Color(0xFF16A34A);
  static const Color _deepPine = Color(0xFF065F46);
  static const Color _deepForest = Color(0xFF064E3B);
  static const Color _mintBg = Color(0xFFF0FDF4);
  static const Color _navyText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _inputBorder = Color(0xFFD0D5DD);
  static const Color _dividerColor = Color(0xFFE2E8F0);
  static const double _buttonHeight = 52.0;
  static const double _inputHeight = 52.0;
  static const double _inputRadius = 10.0;

  // Sign In Form Controllers
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController =
      TextEditingController();
  bool _obscureSignInPassword = true;
  bool _rememberMe = false;

  // Sign Up / Company Registration Form Controllers
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _recruiterNameController =
      TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _signUpPasswordController =
      TextEditingController();
  bool _obscureSignUpPassword = true;
  String? _selectedIndustry;
  bool _agreedToGuidelines = false;

  // Verification & Sign Up OTP Controllers
  final TextEditingController _emailOtpController = TextEditingController();
  String? _pendingSignupEmail;
  Timer? _resendCooldownTimer;
  int _resendCountdown = 0;

  // Forgot Password Controllers
  final TextEditingController _forgotEmailController = TextEditingController();
  final TextEditingController _forgotOtpController = TextEditingController();
  final TextEditingController _forgotNewPasswordController =
      TextEditingController();
  final TextEditingController _forgotConfirmPasswordController =
      TextEditingController();
  bool _obscureForgotNewPassword = true;
  bool _obscureForgotConfirmPassword = true;
  Timer? _forgotResendCooldownTimer;
  int _forgotResendCountdown = 0;

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  late List<String> _industrySectors;

  static const List<String> _defaultIndustrySectors = [
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
    'Other Business Sector',
  ];

  @override
  void initState() {
    super.initState();
    _industrySectors = List.from(_defaultIndustrySectors);
    _selectedIndustry = null;
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => PrivacyPolicyScreen.open(context);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => PrivacyPolicyScreen.open(context);
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _forgotResendCooldownTimer?.cancel();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _companyNameController.dispose();
    _recruiterNameController.dispose();
    _signUpEmailController.dispose();
    _contactPhoneController.dispose();
    _signUpPasswordController.dispose();
    _emailOtpController.dispose();
    _forgotEmailController.dispose();
    _forgotOtpController.dispose();
    _forgotNewPasswordController.dispose();
    _forgotConfirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _startResendCooldown([int seconds = 60]) {
    _resendCooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendCountdown = seconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 1) {
          _resendCountdown--;
        } else {
          _resendCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  void _startForgotResendCooldown([int seconds = 60]) {
    _forgotResendCooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _forgotResendCountdown = seconds);
    _forgotResendCooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_forgotResendCountdown > 1) {
          _forgotResendCountdown--;
        } else {
          _forgotResendCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFDC2626),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _deepPine,
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Auth Handlers ---

  Future<void> _handleSignIn() async {
    if (_isLoading || _isGoogleLoading) return;
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid work email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabaseAuth.signInWithEmail(email: email, password: password);
      if (mounted) setState(() => _isLoading = false);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Sign in failed: ${e.toString()}');
      }
    }
  }

  Future<void> _handleInitiateSignUp() async {
    if (_isLoading || _isGoogleLoading) return;
    final company = _companyNameController.text.trim();
    final recruiter = _recruiterNameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final phone = _contactPhoneController.text.trim();
    final password = _signUpPasswordController.text;

    if (company.isEmpty) {
      _showError('Please enter your Company / Organization name.');
      return;
    }
    if (_selectedIndustry == null || _selectedIndustry!.trim().isEmpty) {
      _showError('Please select your Industry Sector.');
      return;
    }
    if (recruiter.isEmpty) {
      _showError('Please enter the Recruiter / HR Lead name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid official work email address.');
      return;
    }
    if (phone.isNotEmpty && phone.length < 7) {
      _showError('Please enter a valid contact phone number.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (!_agreedToGuidelines) {
      _showError('Please confirm agreement to the Employer Hiring Guidelines.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _supabaseAuth.signUpWithEmail(
        fullName: recruiter,
        email: email,
        password: password,
        role: 'EMPLOYER',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _pendingSignupEmail = email;
          _emailOtpController.clear();
          _screenState = EmployerAuthState.verifyEmail;
        });
        _startResendCooldown(60);
        _showSuccess('Check $email for your verification code.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(
          e is StateError ? e.message : 'Could not create employer account. Try again.',
        );
      }
    }
  }

  Future<void> _handleVerifyEmailOtp() async {
    final email = _pendingSignupEmail;
    final code = _emailOtpController.text.trim();
    if (_isLoading || email == null) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showError('Enter the 6-digit verification code from your email.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabaseAuth.verifySignupOtp(
        email: email,
        token: code,
        role: 'EMPLOYER',
      );
      if (mounted) setState(() => _isLoading = false);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = error.message.toLowerCase();
        if (msg.contains('expired')) {
          _showError('This code has expired. Tap "Resend code" for a fresh code.');
        } else if (msg.contains('invalid') || msg.contains('wrong') || msg.contains('incorrect')) {
          _showError('Incorrect 6-digit code. Please check your email.');
        } else {
          _showError(error.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(
          e is StateError ? e.message : 'The code could not be verified. Try again.',
        );
      }
    }
  }

  Future<void> _handleResendEmailOtp() async {
    final email = _pendingSignupEmail;
    if (email == null || _resendCountdown > 0) return;
    try {
      await _supabaseAuth.resendSignupOtp(email);
      _startResendCooldown(60);
      _showSuccess('Check $email for a new verification code.');
    } catch (e) {
      _showError('Could not resend verification code. Please wait and try again.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading || _isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      await _supabaseAuth.signInWithGoogle();
      if (mounted) setState(() => _isGoogleLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        _showError('Google sign-in could not be completed. Please try again.');
      }
    }
  }

  // --- 2-Step Password Reset Handlers ---

  Future<void> _handleSendForgotPasswordOtp() async {
    if (_isLoading) return;
    final email = _forgotEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter your registered company email.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _supabaseAuth.resetPassword(email: email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _forgotPasswordStep = 2;
          _forgotOtpController.clear();
          _forgotNewPasswordController.clear();
          _forgotConfirmPasswordController.clear();
        });
        _startForgotResendCooldown(60);
        _showSuccess('Verification code sent to $email.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Unable to send verification code. Please check the email.');
      }
    }
  }

  Future<void> _handleVerifyForgotOtpAndResetPassword() async {
    if (_isLoading) return;
    final email = _forgotEmailController.text.trim();
    final otp = _forgotOtpController.text.trim();
    final newPassword = _forgotNewPasswordController.text;
    final confirmPassword = _forgotConfirmPasswordController.text;

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showError('Enter the 6-digit verification code from your email.');
      return;
    }
    if (newPassword.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (newPassword != confirmPassword) {
      _showError('Passwords do not match. Please check and try again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabaseAuth.verifyPasswordResetOtpAndSetPassword(
        email: email,
        token: otp,
        newPassword: newPassword,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _forgotPasswordStep = 1;
          _screenState = EmployerAuthState.signIn;
          _signInEmailController.text = email;
          _signInPasswordController.clear();
        });
        _showSuccess('Password reset successfully! Please sign in with your new password.');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.message.toLowerCase();
        if (msg.contains('expired')) {
          _showError('This code has expired. Tap "Resend code" for a fresh code.');
        } else if (msg.contains('invalid') || msg.contains('wrong') || msg.contains('incorrect')) {
          _showError('Incorrect 6-digit code. Please check your email.');
        } else {
          _showError(e.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e is StateError ? e.message : 'Could not reset password. Please try again.');
      }
    }
  }

  Future<void> _handleResendForgotOtp() async {
    final email = _forgotEmailController.text.trim();
    if (email.isEmpty || _forgotResendCountdown > 0) return;
    try {
      await _supabaseAuth.resendPasswordResetOtp(email: email);
      _startForgotResendCooldown(60);
      _showSuccess('A fresh 6-digit verification code has been sent to $email.');
    } catch (e) {
      _showError('Could not resend code. Please wait and try again.');
    }
  }

  Future<void> _openIndustryPicker() async {
    final result = await SearchableCategoryPickerSheet.show(
      context: context,
      title: 'Choose Industry',
      items: _industrySectors,
      selectedItem: _selectedIndustry,
      defaultIcon: Icons.business_center_outlined,
      searchHint: 'Search Choose Industry...',
    );
    if (result != null && result.trim().isNotEmpty) {
      final trimmed = result.trim();
      setState(() {
        if (!_industrySectors.contains(trimmed)) {
          _industrySectors.insert(0, trimmed);
        }
        _selectedIndustry = trimmed;
      });
    }
  }

  void _handleBackNavigation() {
    if (_screenState == EmployerAuthState.forgotPassword) {
      if (_forgotPasswordStep == 2) {
        _forgotResendCooldownTimer?.cancel();
        setState(() {
          _forgotResendCountdown = 0;
          _forgotPasswordStep = 1;
        });
      } else {
        setState(() {
          _forgotPasswordStep = 1;
          _screenState = EmployerAuthState.signIn;
        });
      }
    } else if (_screenState == EmployerAuthState.signUp) {
      setState(() {
        _screenState = EmployerAuthState.signIn;
      });
    } else if (_screenState == EmployerAuthState.verifyEmail) {
      _resendCooldownTimer?.cancel();
      setState(() {
        _resendCountdown = 0;
        _screenState = EmployerAuthState.signUp;
      });
    } else {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAuthenticationHeader(),
        body: SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: 580,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Emerald & Pine Hero Header
                            _buildAuthHero(),

                            // Elevated Form Card (Stretches Full Height)
                            Expanded(
                              child: Transform.translate(
                                offset: const Offset(0, -28),
                                child: Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(32),
                                      topRight: Radius.circular(32),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x15064E3B),
                                        blurRadius: 24,
                                        offset: Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Sign In / Register Tabs
                                      if (_screenState == EmployerAuthState.signIn ||
                                          _screenState == EmployerAuthState.signUp) ...[
                                        _buildAuthTabs(
                                          isSignIn:
                                              _screenState == EmployerAuthState.signIn,
                                        ),
                                        const SizedBox(height: 24),
                                      ],

                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 260),
                                        switchInCurve: Curves.easeOutCubic,
                                        switchOutCurve: Curves.easeInCubic,
                                        child: KeyedSubtree(
                                          key: ValueKey('${_screenState.name}_$_forgotPasswordStep'),
                                          child: _buildCurrentForm(),
                                        ),
                                      ),

                                      const SizedBox(height: 20),
                                      _buildAuthLegalFooter(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- App Bar ---
  PreferredSizeWidget _buildAuthenticationHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _navyText),
        onPressed: _handleBackNavigation,
      ),
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/career360_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business_center_rounded, color: _emeraldPrimary, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          const Row(
            children: [
              Text(
                'CAREER',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _deepForest,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '360',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _emeraldPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
            ),
            child: const Text(
              'EMPLOYER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF166534),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Hero Section ---
  Widget _buildAuthHero() {
    String badgeText = 'Verified Recruiter Network';
    IconData badgeIcon = Icons.business_center_rounded;
    String heading = 'Recruiter Sign In';
    String description =
        'Access your ATS dashboard, post job vacancies, and connect with top candidates.';

    if (_screenState == EmployerAuthState.signUp) {
      badgeText = 'Company & Recruiter Registration';
      badgeIcon = Icons.domain_add_rounded;
      heading = 'Register Your Company';
      description =
          'Start posting jobs and sourcing verified talent across Tamil Nadu on Career360.';
    } else if (_screenState == EmployerAuthState.verifyEmail) {
      badgeText = 'Work Email Verification';
      badgeIcon = Icons.mark_email_read_outlined;
      heading = 'Verify Company Email';
      description =
          'Enter the 6-digit confirmation code sent to your official recruiter email.';
    } else if (_screenState == EmployerAuthState.forgotPassword) {
      if (_forgotPasswordStep == 1) {
        badgeText = 'Recruiter Access Recovery';
        badgeIcon = Icons.lock_reset_rounded;
        heading = 'Reset Password';
        description =
            'Enter your registered work email and we\'ll send you a 6-digit verification code.';
      } else {
        badgeText = 'Enter Verification Code';
        badgeIcon = Icons.password_rounded;
        heading = 'Set New Password';
        description =
            'Enter the 6-digit code sent to your email and create a new secure password.';
      }
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF064E3B), // Deep Forest Pine
            Color(0xFF065F46), // Primary Dark
            Color(0xFF16A34A), // Emerald Green
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: const Color(0xFF86EFAC)),
                const SizedBox(width: 6),
                Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            heading,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFFD1FAE5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // --- Auth Tabs (Sign In / Register) ---
  Widget _buildAuthTabs({required bool isSignIn}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                scaleDown: 0.97,
                onPressed: () => setState(
                  () => _screenState = EmployerAuthState.signIn,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Recruiter Sign In',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                            isSignIn ? FontWeight.w700 : FontWeight.w600,
                        color: isSignIn ? _emeraldPrimary : _secondaryText,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: BouncyButton(
                scaleDown: 0.97,
                onPressed: () => setState(
                  () => _screenState = EmployerAuthState.signUp,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Register Company',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight:
                            !isSignIn ? FontWeight.w700 : FontWeight.w600,
                        color: !isSignIn ? _emeraldPrimary : _secondaryText,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Stack(
          children: [
            Container(height: 1.5, color: _dividerColor),
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment:
                  isSignIn ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 3.0,
                  decoration: BoxDecoration(
                    color: _emeraldPrimary,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentForm() {
    switch (_screenState) {
      case EmployerAuthState.signIn:
        return _buildSignInForm();
      case EmployerAuthState.signUp:
        return _buildSignUpForm();
      case EmployerAuthState.verifyEmail:
        return _buildVerifyEmailForm();
      case EmployerAuthState.forgotPassword:
        return _buildForgotPasswordForm();
    }
  }

  // ==========================================
  // VIEW 1: SIGN IN FORM
  // ==========================================
  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Official Work Email'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _signInEmailController,
          hint: 'hr@company.com or recruiter@startup.io',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _signInPasswordController,
          hint: 'Enter your password',
          obscureText: _obscureSignInPassword,
          onToggleVisibility: () => setState(
            () => _obscureSignInPassword = !_obscureSignInPassword,
          ),
        ),
        const SizedBox(height: 12),

        // Remember Me & Forgot Password Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: _emeraldPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(color: _inputBorder, width: 1.4),
                    onChanged: (val) =>
                        setState(() => _rememberMe = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            BouncyButton(
              scaleDown: 0.95,
              onPressed: () => setState(() {
                _forgotPasswordStep = 1;
                _screenState = EmployerAuthState.forgotPassword;
              }),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _deepPine,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Sign In to Recruiter Desk',
          icon: Icons.login_rounded,
          onPressed: _handleSignIn,
        ),

        const SizedBox(height: 20),

        // Divider
        Row(
          children: [
            Expanded(child: Container(height: 1, color: _dividerColor)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: _dividerColor)),
          ],
        ),

        const SizedBox(height: 20),

        _buildGoogleSignInButton(),

        const SizedBox(height: 20),

        // Registration Prompter
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'New employer or hiring manager? ',
                style: TextStyle(fontSize: 13.5, color: _secondaryText),
              ),
              BouncyButton(
                scaleDown: 0.95,
                onPressed: () => setState(
                  () => _screenState = EmployerAuthState.signUp,
                ),
                child: const Text(
                  'Register Company',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _deepPine,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 2: REGISTRATION FORM
  // ==========================================
  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Company Name
        _buildFieldLabel('Company / Organization Name *'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _companyNameController,
          hint: 'e.g. Zoho Corporation, Freshworks, Coimbatore Tex',
          prefixIcon: Icons.domain_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),

        // Industry Sector Selector
        _buildFieldLabel('Industry Sector *'),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(_inputRadius),
            onTap: _openIndustryPicker,
            child: Container(
              height: _inputHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_inputRadius),
                border: Border.all(color: _inputBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_center_outlined,
                    size: 20,
                    color: _emeraldPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedIndustry ?? 'Select Industry Sector',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: _selectedIndustry != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _selectedIndustry != null
                            ? _navyText
                            : const Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _secondaryText,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Recruiter Name
        _buildFieldLabel('Recruiter / HR Lead Full Name *'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _recruiterNameController,
          hint: 'e.g. R. Anitha, Senior Talent Acquisition Lead',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),

        // Official Work Email
        _buildFieldLabel('Official Company Work Email *'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _signUpEmailController,
          hint: 'careers@company.com or hr@company.in',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 4),
        const Text(
          'Company domain email preferred for faster employer verification badge.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        // HR Phone
        _buildFieldLabel('Recruiter Contact Phone (Optional)'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _contactPhoneController,
          hint: '+91 98765 43210 or 044-245xxxx',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        // Password
        _buildFieldLabel('Password *'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _signUpPasswordController,
          hint: 'Create a password (min. 6 characters)',
          obscureText: _obscureSignUpPassword,
          onToggleVisibility: () => setState(
            () => _obscureSignUpPassword = !_obscureSignUpPassword,
          ),
        ),
        const SizedBox(height: 16),

        // Agreement Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _agreedToGuidelines,
                activeColor: _emeraldPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                side: const BorderSide(color: _inputBorder, width: 1.4),
                onChanged: (val) =>
                    setState(() => _agreedToGuidelines = val ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I confirm authorization to represent this company and agree to the ',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(
                      text: 'Employer Guidelines',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _deepPine,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => PrivacyPolicyScreen.open(context),
                    ),
                    const TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _deepPine,
                      ),
                      recognizer: _privacyRecognizer,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Register Company & Start Hiring',
          icon: Icons.business_center_rounded,
          onPressed: _handleInitiateSignUp,
        ),

        const SizedBox(height: 20),

        // Sign In switch
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.center,
            children: [
              const Text(
                'Already registered as an employer? ',
                style: TextStyle(fontSize: 13.5, color: _secondaryText),
              ),
              BouncyButton(
                scaleDown: 0.95,
                onPressed: () => setState(
                  () => _screenState = EmployerAuthState.signIn,
                ),
                child: const Text(
                  'Sign In to Recruiter Desk',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _deepPine,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 3: OTP VERIFICATION (SIGN UP)
  // ==========================================
  Widget _buildVerifyEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _mintBg,
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: _deepPine,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check your work inbox',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _deepForest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Check ${_pendingSignupEmail ?? 'your email'} for a 6-digit code. If you used this email before, sign in instead.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        _buildFieldLabel('6-Digit Verification Code'),
        const SizedBox(height: 6),
        SizedBox(
          height: _inputHeight,
          child: TextFormField(
            controller: _emailOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: _navyText,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              hintStyle: const TextStyle(
                fontSize: 18,
                letterSpacing: 6,
                color: Color(0xFF98A2B3),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: const BorderSide(color: _inputBorder, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: const BorderSide(color: _emeraldPrimary, width: 1.8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Verify Email & Activate Recruiter Desk',
          icon: Icons.check_circle_rounded,
          onPressed: _handleVerifyEmailOtp,
        ),

        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _resendCooldownTimer?.cancel();
                setState(() {
                  _resendCountdown = 0;
                  _emailOtpController.clear();
                  _screenState = EmployerAuthState.signUp;
                });
              },
              child: const Text(
                'Change email',
                style: TextStyle(
                  color: _deepPine,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _resendCountdown > 0 ? null : _handleResendEmailOtp,
              child: Text(
                _resendCountdown > 0
                    ? 'Resend code in ${_resendCountdown}s'
                    : 'Resend code',
                style: TextStyle(
                  color: _resendCountdown > 0 ? _secondaryText : _deepPine,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            _resendCooldownTimer?.cancel();
            _signInEmailController.text = _pendingSignupEmail ?? '';
            setState(() => _screenState = EmployerAuthState.signIn);
          },
          child: const Text('Already registered? Sign in'),
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 4: 2-STEP FORGOT PASSWORD FLOW
  // ==========================================
  Widget _buildForgotPasswordForm() {
    if (_forgotPasswordStep == 1) {
      return _buildForgotEmailStep();
    }
    return _buildForgotVerifyAndResetStep();
  }

  Widget _buildForgotEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Registered Work Email *'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _forgotEmailController,
          hint: 'hr@company.com',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Send Verification Code',
          icon: Icons.send_rounded,
          onPressed: _handleSendForgotPasswordOtp,
        ),

        const SizedBox(height: 22),

        Center(
          child: BouncyButton(
            scaleDown: 0.95,
            onPressed: () {
              setState(() {
                _forgotPasswordStep = 1;
                _screenState = EmployerAuthState.signIn;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: _emeraldPrimary),
                  SizedBox(width: 6),
                  Text(
                    'Back to Recruiter Sign In',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _deepPine,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotVerifyAndResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _mintBg,
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: _deepPine,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification code sent',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _deepForest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter the 6-digit code sent to ${_forgotEmailController.text.trim()} to reset your password.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // OTP Field
        _buildFieldLabel('6-Digit Verification Code *'),
        const SizedBox(height: 6),
        SizedBox(
          height: _inputHeight,
          child: TextFormField(
            controller: _forgotOtpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: _navyText,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • • • •',
              hintStyle: const TextStyle(
                fontSize: 18,
                letterSpacing: 6,
                color: Color(0xFF98A2B3),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: const BorderSide(color: _inputBorder, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: const BorderSide(color: _emeraldPrimary, width: 1.8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // New Password
        _buildFieldLabel('New Password *'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _forgotNewPasswordController,
          hint: 'Enter new password (min. 6 characters)',
          obscureText: _obscureForgotNewPassword,
          onToggleVisibility: () => setState(
            () => _obscureForgotNewPassword = !_obscureForgotNewPassword,
          ),
        ),
        const SizedBox(height: 14),

        // Confirm New Password
        _buildFieldLabel('Confirm New Password *'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _forgotConfirmPasswordController,
          hint: 'Re-enter new password to confirm',
          obscureText: _obscureForgotConfirmPassword,
          onToggleVisibility: () => setState(
            () => _obscureForgotConfirmPassword = !_obscureForgotConfirmPassword,
          ),
        ),

        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Reset & Save Password',
          icon: Icons.check_circle_rounded,
          onPressed: _handleVerifyForgotOtpAndResetPassword,
        ),

        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _forgotResendCooldownTimer?.cancel();
                setState(() {
                  _forgotResendCountdown = 0;
                  _forgotOtpController.clear();
                  _forgotPasswordStep = 1;
                });
              },
              child: const Text(
                'Change email',
                style: TextStyle(
                  color: _deepPine,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _forgotResendCountdown > 0 ? null : _handleResendForgotOtp,
              child: Text(
                _forgotResendCountdown > 0
                    ? 'Resend code in ${_forgotResendCountdown}s'
                    : 'Resend code',
                style: TextStyle(
                  color: _forgotResendCountdown > 0 ? _secondaryText : _deepPine,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Center(
          child: BouncyButton(
            scaleDown: 0.95,
            onPressed: () {
              setState(() {
                _forgotPasswordStep = 1;
                _screenState = EmployerAuthState.signIn;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: _emeraldPrimary),
                  SizedBox(width: 6),
                  Text(
                    'Back to Recruiter Sign In',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _deepPine,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Shared Form Field Builders ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  Widget _buildFormInput({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return SizedBox(
      height: _inputHeight,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, color: _navyText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFF94A3B8)),
          prefixIcon: Icon(prefixIcon, color: _secondaryText, size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: _inputBorder, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: _emeraldPrimary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return SizedBox(
      height: _inputHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 15, color: _navyText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14.0, color: Color(0xFF94A3B8)),
          prefixIcon:
              const Icon(Icons.lock_outline_rounded, color: _secondaryText, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _secondaryText,
              size: 20,
            ),
            onPressed: onToggleVisibility,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: _inputBorder, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
            borderSide: const BorderSide(color: _emeraldPrimary, width: 1.8),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    final bool isEnabled = !_isLoading && !_isGoogleLoading;
    return BouncyButton(
      onPressed: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(_inputRadius),
      child: Container(
        height: _buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [_deepPine, _emeraldPrimary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: isEnabled ? null : _emeraldPrimary.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(_inputRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: _emeraldPrimary.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      key: ValueKey(label),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    final bool isEnabled = !_isLoading && !_isGoogleLoading;
    return BouncyButton(
      onPressed: isEnabled ? _handleGoogleSignIn : null,
      borderRadius: BorderRadius.circular(_inputRadius),
      pressOverlayColor: _emeraldPrimary.withValues(alpha: 0.10),
      child: Container(
        height: _buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_inputRadius),
          border: Border.all(color: _inputBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _isGoogleLoading
                ? const Row(
                    key: ValueKey('google_loading'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _emeraldPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Connecting to Google Workspace...',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _navyText,
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('google_idle'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/google_logo.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 26,
                              color: Color(0xFF4285F4),
                            ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Work Google Account',
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: _navyText,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthLegalFooter() {
    return Column(
      children: [
        Center(
          child: Text.rich(
            TextSpan(
              text: 'By continuing, you agree to our ',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _deepPine,
                  ),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _deepPine,
                  ),
                  recognizer: _privacyRecognizer,
                ),
                const TextSpan(text: '.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Recruiter Helpdesk: ${AppConstants.supportEmail}',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
