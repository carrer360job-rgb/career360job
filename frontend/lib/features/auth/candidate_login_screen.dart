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

  // Design Tokens (Corporate Blue Design System)
  static const Color _primaryBlue = Color(0xFF155EEF);
  static const Color _navyText = Color(0xFF101828);
  static const Color _secondaryText = Color(0xFF667085);
  static const Color _inputBorderColor = Color(0xFFD0D5DD);
  static const Color _inputBgColor = Colors.white;
  static const double _elementHeight = 56.0;
  static const double _borderRadius = 10.0;

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

  // --- Actions ---

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32, // Accommodates safe vertical padding
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header & Branding Section
                      _buildBrandHeader(),
                      const SizedBox(height: 24),

                      // 2. Main Full-Screen Content Views
                      if (_screenState == AuthScreenState.signIn) ...[
                        _buildSignInView(),
                      ] else if (_screenState == AuthScreenState.signUp) ...[
                        _buildSignUpView(),
                      ] else if (_screenState == AuthScreenState.verifyOtp) ...[
                        _buildVerifyOtpView(),
                      ] else if (_screenState == AuthScreenState.forgotPassword) ...[
                        _buildForgotPasswordView(),
                      ],

                      // 3. Flexible Spacer to push footer to the bottom on tall viewports
                      const Spacer(),
                      const SizedBox(height: 24),

                      // 4. Clean Footer - strictly ONE continuous line
                      _buildFooterTerms(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Header with Back Button (when applicable), Logo, and Tagline
  Widget _buildBrandHeader() {
    final showBack = _screenState == AuthScreenState.verifyOtp ||
        _screenState == AuthScreenState.forgotPassword;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (showBack)
          Positioned(
            left: 0,
            child: IconButton(
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
          )
        else
          Positioned(
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _navyText, size: 24),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: widget.onBack,
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Clean circular blue brand icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.work_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Career360',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Find. Apply. Grow.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _secondaryText,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Segmented Tab Switcher: [ Sign In ] | [ Sign Up ]
  Widget _buildSegmentedSwitcher({required bool isSignIn}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(_borderRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _screenState = AuthScreenState.signIn;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSignIn ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(_borderRadius - 2),
                  boxShadow: isSignIn
                      ? [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isSignIn ? Colors.white : _secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _screenState = AuthScreenState.signUp;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !isSignIn ? _primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(_borderRadius - 2),
                  boxShadow: !isSignIn
                      ? [
                          BoxShadow(
                            color: _primaryBlue.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: !isSignIn ? Colors.white : _secondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW 1: SIGN IN ("Welcome Back")
  // ==========================================
  Widget _buildSignInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Section
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _navyText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to your Career360 account and continue your journey.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Equal-width Segmented Switcher
        _buildSegmentedSwitcher(isSignIn: true),
        const SizedBox(height: 24),

        // Email Field (56px)
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Password Field (56px)
        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signInPasswordController,
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignInPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignInPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: const Color(0xFF98A2B3),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
          ),
        ),
        const SizedBox(height: 14),

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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: _inputBorderColor, width: 1.4),
                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(fontSize: 13, color: Color(0xFF344054), fontWeight: FontWeight.w500),
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
        const SizedBox(height: 24),

        // Primary CTA Button (56px)
        _buildPrimaryButton(
          label: 'Sign In →',
          onPressed: _handleSignIn,
        ),
        const SizedBox(height: 20),

        // Subtle Divider with "or"
        _buildDivider(),
        const SizedBox(height: 20),

        // Google Sign-In Button (56px)
        _buildGoogleButton(),
      ],
    );
  }

  // ==========================================
  // VIEW 2: SIGN UP ("Create Your Account")
  // ==========================================
  Widget _buildSignUpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Section
        const Text(
          'Create Your Account',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _navyText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Join Career360 and take the next step in your career.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Equal-width Segmented Switcher
        _buildSegmentedSwitcher(isSignIn: false),
        const SizedBox(height: 24),

        // Full Name Field (56px)
        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpNameController,
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),

        // Email Field (56px)
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Password Field (56px)
        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _signUpPasswordController,
          hint: 'Create a password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignUpPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: const Color(0xFF98A2B3),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use at least 8 characters with a mix of letters, numbers and symbols.',
          style: TextStyle(fontSize: 12, color: _secondaryText, height: 1.3),
        ),
        const SizedBox(height: 24),

        // Primary CTA Button (56px)
        _buildPrimaryButton(
          label: 'Create Account & Send OTP →',
          onPressed: _handleInitiateSignUp,
        ),
        const SizedBox(height: 20),

        // Subtle Divider with "or"
        _buildDivider(),
        const SizedBox(height: 20),

        // Google Sign-In Button (56px)
        _buildGoogleButton(),
      ],
    );
  }

  // ==========================================
  // VIEW 3: VERIFY EMAIL OTP
  // ==========================================
  Widget _buildVerifyOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _navyText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'We\'ve sent a 6-digit verification code to your email address.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),

        // Email Badge Card with [ Edit ]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(_borderRadius),
            border: Border.all(color: _inputBorderColor, width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded, size: 20, color: _primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pendingOtpEmail.isNotEmpty ? _pendingOtpEmail : 'dhinesh.v@example.com',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _navyText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _screenState = AuthScreenState.signUp;
                  });
                },
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Enter 6-digit code',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 10),

        // Six OTP Digit Boxes (56px height)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpDigitBox(index)),
        ),
        const SizedBox(height: 20),

        // Resend Timer Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded, size: 16, color: _secondaryText),
            const SizedBox(width: 6),
            Text(
              _resendCountdown > 0
                  ? 'Resend in 00:${_resendCountdown.toString().padLeft(2, '0')}'
                  : 'Didn\'t receive code? ',
              style: const TextStyle(fontSize: 13.5, color: _secondaryText),
            ),
            if (_resendCountdown == 0)
              GestureDetector(
                onTap: _handleResendOtp,
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _primaryBlue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Verify Button (56px)
        _buildPrimaryButton(
          label: 'Verify Code & Complete Sign Up →',
          onPressed: _handleVerifyEmailOtp,
        ),
      ],
    );
  }

  // ==========================================
  // VIEW 4: FORGOT PASSWORD?
  // ==========================================
  Widget _buildForgotPasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: _navyText,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _forgotEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),

        // Primary Button (56px)
        _buildPrimaryButton(
          label: 'Send Reset Link',
          onPressed: _handleSendResetLink,
        ),

        // Success Confirmation Card
        if (_resetLinkSent) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(_borderRadius),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset link sent!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'If the email is registered, you\'ll receive a password reset link shortly.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF047857),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Back to Sign In Link
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
                    fontSize: 14,
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

  // --- Helper Widgets matching Design System ---

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF344054),
      ),
    );
  }

  /// 56px High Text Input Field
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return SizedBox(
      height: _elementHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15, color: _navyText),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF98A2B3)),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF98A2B3), size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: _inputBgColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: _inputBorderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: _primaryBlue, width: 1.8),
          ),
        ),
      ),
    );
  }

  /// 56px High OTP Box
  Widget _buildOtpDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: _elementHeight,
      child: TextFormField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _navyText,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: _inputBgColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            borderSide: const BorderSide(color: _inputBorderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
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

  /// 56px High Primary Action Button
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: _elementHeight,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }

  /// Subtle Divider with "or"
  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFEAECF0), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _secondaryText,
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFEAECF0), thickness: 1)),
      ],
    );
  }

  /// 56px High Google Sign-In Button
  Widget _buildGoogleButton() {
    return SizedBox(
      height: _elementHeight,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: _inputBorderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata_rounded,
                size: 26,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
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
                fontSize: 12,
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
}
