import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/firebase_auth_service.dart';
import '../legal/privacy_policy_screen.dart';

enum AuthScreenState {
  signIn,
  signUp,
  verifyOtp,
  forgotPassword,
}

class CandidateLoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onBack;

  const CandidateLoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onBack,
  });

  @override
  State<CandidateLoginScreen> createState() => _CandidateLoginScreenState();
}

class _CandidateLoginScreenState extends State<CandidateLoginScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  AuthScreenState _screenState = AuthScreenState.signIn;

  // Design Tokens based on Reference Mockup
  static const Color _primaryBlue = Color(0xFF0D6EFD);
  static const Color _navyText = Color(0xFF0F172A);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _inputBorderColor = Color(0xFFE2E8F0);
  static const double _cardRadius = 24.0;
  static const double _inputRadius = 12.0;

  // Sign In Form Controllers
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController = TextEditingController();
  bool _obscureSignInPassword = true;
  bool _rememberMe = false;

  // Sign Up Form Controllers
  final TextEditingController _signUpNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();
  bool _obscureSignUpPassword = true;

  // Forgot Password Controllers
  final TextEditingController _forgotEmailController = TextEditingController();
  bool _resetLinkSent = false;

  // OTP Verification State
  String _pendingOtpEmail = '';
  String _pendingOtpName = '';
  String _pendingOtpPassword = '';
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 45;
  Timer? _timer;

  bool _isLoading = false;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => PrivacyPolicyScreen.open(context);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => PrivacyPolicyScreen.open(context);
  }

  @override
  void dispose() {
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _forgotEmailController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _startResendTimer([int seconds = 45]) {
    _timer?.cancel();
    setState(() {
      _resendCountdown = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // --- Handlers ---

  Future<void> _handleSignIn() async {
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter your password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        widget.onLoginSuccess();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Sign in failed. Please check credentials.';
        if (e.code == 'user-not-found') {
          message = 'No account found with this email. Please sign up.';
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address format.';
        }
        _showError(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Sign in failed: ${e.toString()}');
      }
    }
  }

  Future<void> _handleInitiateSignUp() async {
    final name = _signUpNameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;

    if (name.isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    setState(() => _isLoading = true);

    final res = await _authService.sendEmailOtp(
      email: email,
      name: name,
      type: 'signup',
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _pendingOtpEmail = email;
        _pendingOtpName = name;
        _pendingOtpPassword = password;
        _screenState = AuthScreenState.verifyOtp;

        for (final c in _otpControllers) {
          c.clear();
        }
        _startResendTimer(res['resendWaitSeconds'] ?? 45);
        _otpFocusNodes[0].requestFocus();

        _showSuccess('Verification code sent to your email.');
      } else {
        _showError(res['message'] ?? 'Failed to send verification code.');
      }
    }
  }

  Future<void> _handleVerifyEmailOtp() async {
    final otpCode = _otpControllers.map((c) => c.text.trim()).join();
    if (otpCode.length < 6) {
      _showError('Please enter the full 6-digit verification code.');
      return;
    }

    setState(() => _isLoading = true);

    final res = await _authService.verifyEmailOtp(
      email: _pendingOtpEmail,
      otp: otpCode,
      name: _pendingOtpName,
      password: _pendingOtpPassword,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _showSuccess('Email verified successfully!');
        widget.onLoginSuccess();
      } else {
        _showError(res['message'] ?? 'Invalid or expired code.');
      }
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() => _isLoading = true);

    final res = await _authService.sendEmailOtp(
      email: _pendingOtpEmail,
      name: _pendingOtpName,
      type: 'signup',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        _startResendTimer(res['resendWaitSeconds'] ?? 45);
        _showSuccess('New verification code sent to your email.');
      } else {
        _showError(res['message'] ?? 'Failed to resend code.');
      }
    }
  }

  Future<void> _handleSendResetLink() async {
    final email = _forgotEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _resetLinkSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not send reset email. Verify the email address.');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final cred = await _authService.signInWithGoogle();
      if (mounted) {
        setState(() => _isLoading = false);
        if (cred != null) {
          widget.onLoginSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Google sign-in was cancelled or encountered an error.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.error,
        content: Text(message),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FF),
      body: Stack(
        children: [
          // 1. Decorative Atmosphere: Soft Blue Curves & 3D Briefcase Art
          Positioned.fill(
            child: CustomPaint(
              painter: _AtmospherePainter(),
            ),
          ),

          // 3D Briefcase Art at Top-Right
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 16,
            child: _buildBriefcaseIllustration(),
          ),

          // 2. Main Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Back button (when applicable)
                  _buildTopNav(),

                  // Brand Header (Logo Icon + "Career360" + "Find. Apply. Grow.")
                  _buildBrandHeader(),
                  const SizedBox(height: 18),

                  // Title & Subtitle Section
                  _buildWelcomeHeader(),
                  const SizedBox(height: 18),

                  // Elegant White Floating Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_cardRadius),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_screenState == AuthScreenState.signIn) ...[
                          _buildSignInForm(),
                        ] else if (_screenState == AuthScreenState.signUp) ...[
                          _buildSignUpForm(),
                        ] else if (_screenState == AuthScreenState.verifyOtp) ...[
                          _buildVerifyOtpForm(),
                        ] else if (_screenState == AuthScreenState.forgotPassword) ...[
                          _buildForgotPasswordForm(),
                        ],

                        const SizedBox(height: 20),

                        // Footer Terms: strictly ONE single line
                        _buildFooterTerms(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Top Navigation (Back button when applicable)
  Widget _buildTopNav() {
    final canGoBack = _screenState == AuthScreenState.verifyOtp ||
        _screenState == AuthScreenState.forgotPassword;

    if (!canGoBack) {
      return const SizedBox(height: 8);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _navyText, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              setState(() {
                _resetLinkSent = false;
                _screenState = AuthScreenState.signIn;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Brand Header matching Reference Design
  Widget _buildBrandHeader() {
    return Row(
      children: [
        // Circular C-Logo with Briefcase inside
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF0D6EFD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D6EFD).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.work_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Career360',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _primaryBlue,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Find. Apply. Grow.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _secondaryText.withValues(alpha: 0.9),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Title & Subtitle Section
  Widget _buildWelcomeHeader() {
    String title = 'Welcome Back';
    String subtitle = 'Sign in to your Career360 account\nand continue your journey.';

    if (_screenState == AuthScreenState.signUp) {
      title = 'Create Your Account';
      subtitle = 'Join Career360 and take the next step\nin your career.';
    } else if (_screenState == AuthScreenState.verifyOtp) {
      title = 'Verify Your Email';
      subtitle = 'We\'ve sent a 6-digit verification code to\nyour email address.';
    } else if (_screenState == AuthScreenState.forgotPassword) {
      title = 'Forgot Password?';
      subtitle = 'Enter your email address and we\'ll send you\na link to reset your password.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _navyText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Segmented Tab Switcher matching Image: Blue Pill with Icon
  Widget _buildSegmentedSwitcher({required bool isSignIn}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _screenState = AuthScreenState.signIn),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSignIn ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSignIn
                      ? [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: isSignIn ? Colors.white : const Color(0xFF475467),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isSignIn ? Colors.white : const Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _screenState = AuthScreenState.signUp),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !isSignIn ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !isSignIn
                      ? [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 18,
                      color: !isSignIn ? Colors.white : const Color(0xFF475467),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: !isSignIn ? Colors.white : const Color(0xFF475467),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 1: SIGN IN FORM
  // ==========================================
  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSegmentedSwitcher(isSignIn: true),
        const SizedBox(height: 20),

        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInPasswordController,
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignInPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
          ),
        ),
        const SizedBox(height: 12),

        // Remember me & Forgot Password
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
                    activeColor: _primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475467), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _forgotEmailController.text = _signInEmailController.text;
                  _resetLinkSent = false;
                  _screenState = AuthScreenState.forgotPassword;
                });
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Sign In Button
        _buildPrimaryButton(
          label: 'Sign In  ➔',
          onPressed: _handleSignIn,
        ),
        const SizedBox(height: 18),

        _buildDivider('or'),
        const SizedBox(height: 16),

        _buildGoogleButton(),
      ],
    );
  }

  // ==========================================
  // VIEW 2: SIGN UP FORM
  // ==========================================
  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSegmentedSwitcher(isSignIn: false),
        const SizedBox(height: 20),

        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpNameController,
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpPasswordController,
          hint: 'Create a password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignUpPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use at least 8 characters with a mix of letters, numbers and symbols.',
          style: TextStyle(fontSize: 11.5, color: _secondaryText, height: 1.3),
        ),
        const SizedBox(height: 20),

        // Primary Button
        _buildPrimaryButton(
          label: 'Create Account & Send OTP  ➔',
          onPressed: _handleInitiateSignUp,
        ),
        const SizedBox(height: 18),

        _buildDivider('or'),
        const SizedBox(height: 16),

        _buildGoogleButton(),
      ],
    );
  }

  // ==========================================
  // VIEW 3: VERIFY EMAIL OTP FORM
  // ==========================================
  Widget _buildVerifyOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Badge Box with [ Edit ]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _inputBorderColor, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 18, color: _primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pendingOtpEmail.isNotEmpty ? _pendingOtpEmail : 'dhinesh.v@example.com',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _navyText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _screenState = AuthScreenState.signUp),
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Enter 6-digit code',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),

        // 6 OTP Digit Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpBox(index)),
        ),
        const SizedBox(height: 16),

        // Countdown Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded, size: 15, color: _secondaryText),
            const SizedBox(width: 6),
            Text(
              _resendCountdown > 0
                  ? 'Resend in 00:${_resendCountdown.toString().padLeft(2, '0')}'
                  : 'Didn\'t receive code? ',
              style: const TextStyle(fontSize: 13, color: _secondaryText),
            ),
            if (_resendCountdown == 0)
              GestureDetector(
                onTap: _handleResendOtp,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),

        _buildPrimaryButton(
          label: 'Verify Code & Complete Sign Up  ➔',
          onPressed: _handleVerifyEmailOtp,
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 4: FORGOT PASSWORD FORM
  // ==========================================
  Widget _buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _forgotEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        _buildPrimaryButton(
          label: 'Send Reset Link',
          onPressed: _handleSendResetLink,
        ),

        if (_resetLinkSent) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset link sent!',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'If the email is registered, you\'ll receive a password reset link shortly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        Center(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _resetLinkSent = false;
                _screenState = AuthScreenState.signIn;
              });
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded, size: 16, color: _primaryBlue),
                SizedBox(width: 6),
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: _navyText,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14.5, color: _navyText),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: const BorderSide(color: _inputBorderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 46,
      height: 52,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _navyText,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _inputBorderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primaryBlue, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _otpFocusNodes[index + 1].requestFocus();
            } else {
              _otpFocusNodes[index].unfocus();
              _handleVerifyEmailOtp();
            }
          } else if (value.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: _primaryBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _inputBorderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_inputRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              width: 19,
              height: 19,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata_rounded,
                size: 26,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single Line Terms & Policy Footer with Shield Icon
  Widget _buildFooterTerms() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 15,
            color: _primaryBlue,
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: _secondaryText,
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
              ),
              children: [
                const TextSpan(text: 'By continuing, you agree to our '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Privacy Policy.',
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _privacyRecognizer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3D Briefcase Illustration in Top Right (Native Vector Art)
  Widget _buildBriefcaseIllustration() {
    return Transform.rotate(
      angle: -0.12,
      child: Container(
        width: 105,
        height: 85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(4, 12),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Handle on Top
            Positioned(
              top: 4,
              child: Container(
                width: 36,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 3),
                ),
              ),
            ),
            // Horizontal Leather Strap Line
            Positioned(
              top: 36,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            // Metallic Center Clasp
            Positioned(
              top: 30,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Canvas Painter for Smooth Fluid Blue Curves matching the Reference
class _AtmospherePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Top-Right Soft Wave Blob
    final topPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.9, -0.6),
        radius: 0.8,
        colors: [
          const Color(0xFFDCEBFE).withValues(alpha: 0.8),
          const Color(0xFFEBF3FE).withValues(alpha: 0.4),
          const Color(0xFFF2F7FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));

    final topPath = Path()
      ..moveTo(size.width * 0.45, 0)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.22, size.width, size.height * 0.28)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(topPath, topPaint);

    // 2. Decorative Soft Circle Bubble at Top Right
    final circlePaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.94, size.height * 0.11), 6, circlePaint);

    // 3. Bottom Smooth Swooshing Wave
    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFDCEBFE), Color(0xFFBFDBFE)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, size.height * 0.88, size.width, size.height * 0.12));

    final bottomPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.96, size.width, size.height * 0.91)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
