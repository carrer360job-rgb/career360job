import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/firebase_auth_service.dart';
import '../legal/privacy_policy_screen.dart';

enum AuthMode { signIn, signUp }

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
  AuthMode _authMode = AuthMode.signIn;

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

  // Email OTP Verification State
  bool _isVerifyingOtp = false;
  String _pendingOtpEmail = '';
  String _pendingOtpName = '';
  String _pendingOtpPassword = '';
  String _otpType = 'signup'; // 'signup' or 'reset'
  
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

  /// Sign In with Email & Password
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

  /// Initiate Sign Up with 6-Digit Email OTP
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
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
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
        _otpType = 'signup';
        _isVerifyingOtp = true;

        for (final c in _otpControllers) {
          c.clear();
        }
        _startResendTimer(res['resendWaitSeconds'] ?? 45);
        _otpFocusNodes[0].requestFocus();

        _showSuccess(res['message'] ?? 'Verification code sent to your email.');
      } else {
        _showError(res['message'] ?? 'Failed to send verification code.');
      }
    }
  }

  /// Verify 6-Digit Email OTP
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
        _showSuccess(res['message'] ?? 'Email verified successfully!');
        widget.onLoginSuccess();
      } else {
        _showError(res['message'] ?? 'Invalid or expired code.');
      }
    }
  }

  /// Resend Email OTP
  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() => _isLoading = true);

    final res = await _authService.sendEmailOtp(
      email: _pendingOtpEmail,
      name: _pendingOtpName,
      type: _otpType,
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

  /// Forgot Password Flow
  Future<void> _handleForgotPassword() async {
    final email = _signInEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter your email above to reset password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordReset(email);
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccess('Password reset link sent to $email. Please check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not send reset email. Verify the email address.');
      }
    }
  }

  /// Google 1-Tap Sign-In
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0B1F3A)),
          onPressed: () {
            if (_isVerifyingOtp) {
              setState(() => _isVerifyingOtp = false);
            } else {
              widget.onBack();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Branding Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Main Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: _isVerifyingOtp
                        ? _buildEmailOtpVerificationView()
                        : _buildAuthFormView(),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// App Logo & Tagline Header
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD1E0FF), width: 1.2),
          ),
          child: const Center(
            child: Icon(
              Icons.work_outline_rounded,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Career360',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0B1F3A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Find Your Next Career Move',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  /// Main View: Tab Selector + Form
  Widget _buildAuthFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab Selector: [ Sign In ] | [ Sign Up ]
        _buildTabSelector(),
        const SizedBox(height: 20),

        if (_authMode == AuthMode.signIn) ...[
          _buildSignInForm(),
        ] else ...[
          _buildSignUpForm(),
        ],

        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 16),
        _buildGoogleButton(),
        const SizedBox(height: 20),
        _buildFooterTerms(),
      ],
    );
  }

  /// Tab Selector Widget
  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              title: 'Sign In',
              icon: Icons.lock_outline_rounded,
              isSelected: _authMode == AuthMode.signIn,
              onTap: () => setState(() => _authMode = AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              title: 'Sign Up',
              icon: Icons.person_add_alt_1_outlined,
              isSelected: _authMode == AuthMode.signUp,
              onTap: () => setState(() => _authMode = AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0B1F3A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sign In Form Fields
  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _signInEmailController,
          hint: 'alex.turner@example.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _signInPasswordController,
          hint: '••••••••••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignInPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignInPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
              size: 18,
            ),
            onPressed: () => setState(() => _obscureSignInPassword = !_obscureSignInPassword),
          ),
        ),
        const SizedBox(height: 10),

        // Remember Me & Forgot Password
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
                    activeColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Remember me',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
                ),
              ],
            ),
            GestureDetector(
              onTap: _handleForgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Sign In Button
        _buildPrimaryButton(
          label: 'Sign In  ➔',
          onPressed: _handleSignIn,
        ),
      ],
    );
  }

  /// Sign Up Form Fields
  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _signUpNameController,
          hint: 'Alex Turner',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _signUpEmailController,
          hint: 'alex.turner@example.com',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Create Password'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _signUpPasswordController,
          hint: 'At least 6 characters',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureSignUpPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: const Color(0xFF94A3B8),
              size: 18,
            ),
            onPressed: () => setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Must be at least 6 characters',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 18),

        // Create Account & Send OTP Button
        _buildPrimaryButton(
          label: 'Create Account & Send OTP  ➔',
          onPressed: _handleInitiateSignUp,
        ),
      ],
    );
  }

  /// 6-Digit Email OTP Verification View
  Widget _buildEmailOtpVerificationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _isVerifyingOtp = false),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 4),
                  Text(
                    'Back to form',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text(
          'Verify Your Email Address',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B1F3A),
          ),
        ),
        const SizedBox(height: 6),

        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475467)),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to: '),
                    TextSpan(
                      text: _pendingOtpEmail,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0B1F3A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isVerifyingOtp = false),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'Edit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'Enter 6-Digit Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 10),

        // 6 OTP Digit Boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpDigitBox(index)),
        ),
        const SizedBox(height: 16),

        // Countdown Timer & Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _resendCountdown > 0
                  ? 'Didn\'t receive code? Resend in 00:${_resendCountdown.toString().padLeft(2, '0')}'
                  : 'Didn\'t receive code? ',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            if (_resendCountdown == 0)
              GestureDetector(
                onTap: _handleResendOtp,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),

        // Verify Button
        _buildPrimaryButton(
          label: 'Verify Code & Complete Sign Up  ➔',
          onPressed: _handleVerifyEmailOtp,
        ),
      ],
    );
  }

  /// 6-Digit OTP Box with Auto-Advance & Backspace
  Widget _buildOtpDigitBox(int index) {
    return SizedBox(
      width: 44,
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
          color: Color(0xFF0B1F3A),
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
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

  /// Helper: Field Label
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  /// Helper: Text Field
  Widget _buildTextField({
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
      style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF94A3B8), size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  /// Helper: Primary Blue Button
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Helper: Divider ("or continue with")
  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    );
  }

  /// Helper: Google 1-Tap Sign-In Button
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata_rounded,
                size: 24,
                color: Color(0xFF4285F4),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper: Footer Terms - STRICTLY ON ONE SINGLE LINE
  Widget _buildFooterTerms() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 14,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
              ),
              children: [
                TextSpan(
                  text: _authMode == AuthMode.signIn
                      ? 'By continuing, you agree to our '
                      : 'By signing up, you agree to our ',
                ),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Privacy Policy.',
                  style: const TextStyle(
                    color: AppTheme.primary,
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
