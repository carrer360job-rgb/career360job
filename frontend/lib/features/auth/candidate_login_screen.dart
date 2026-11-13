import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/services/firebase_auth_service.dart';
import '../../core/widgets/bouncy_button.dart';
import '../legal/privacy_policy_screen.dart';

enum AuthScreenState { signIn, signUp, forgotPassword }

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

  // Strict Design Tokens from Reference Screenshot
  static const Color _primaryBlue = Color(0xFF155EEF);
  static const Color _deepNavy = Color(0xFF0B347C);
  static const Color _secondaryBlue = Color(0xFF1765E8);
  static const Color _navyText = Color(0xFF101828);
  static const Color _secondaryText = Color(0xFF667085);
  static const Color _inputBorder = Color(0xFFD0D5DD);
  static const Color _dividerColor = Color(0xFFE4E7EC);
  static const Color _successGreen = Color(0xFF039855);
  static const double _buttonHeight = 52.0;
  static const double _inputHeight = 52.0;
  static const double _inputRadius = 10.0;

  // Sign In Form Controllers
  final TextEditingController _signInEmailController = TextEditingController();
  final TextEditingController _signInPasswordController =
      TextEditingController();
  bool _obscureSignInPassword = true;
  bool _rememberMe = false;

  // Sign Up Form Controllers
  final TextEditingController _signUpNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController =
      TextEditingController();
  bool _obscureSignUpPassword = true;

  // Forgot Password Controllers
  final TextEditingController _forgotEmailController = TextEditingController();
  bool _resetLinkSent = false;

  bool _isLoading = false;
  bool _isGoogleLoading = false;

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
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
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
      await _authService.signInWithEmail(email: email, password: password);
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
        } else if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          message = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address format.';
        } else if (e.code == 'user-disabled') {
          message = 'This account has been disabled. Please contact support.';
        } else if (e.code == 'email-not-verified') {
          message = 'We sent you a verification email. Verify your address, then sign in again.';
        } else if (e.code == 'too-many-requests') {
          message =
              'Too many failed attempts. Please wait a moment and try again.';
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

    try {
      await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _screenState = AuthScreenState.signIn;
          _signInEmailController.text = email;
          _signInPasswordController.clear();
        });
        _showSuccess(
          'Verification link sent. Verify your email, then sign in.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Sign up failed. Please try again.';
        if (e.code == 'email-already-in-use') {
          message =
              'An account already exists with this email. Please sign in.';
        } else if (e.code == 'weak-password') {
          message = 'Password is too weak. Please use a stronger password.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address format.';
        }
        _showError(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Sign up failed: ${e.toString()}');
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
        _showSuccess('Password reset link sent to your email via Firebase.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String message = 'Failed to send password reset email.';
        if (e.code == 'user-not-found') {
          message = 'No account found with this email address.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address format.';
        }
        _showError(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Unable to send reset link: ${e.toString()}');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final cred = await _authService.signInWithGoogle();
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        if (cred != null) {
          _showSuccess(
            'Welcome back, ${cred.user?.displayName ?? "Candidate"}!',
          );
          widget.onLoginSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        debugPrint('[Google Sign-In Error]: $e');
        String errMsg = e.toString();
        if (errMsg.contains('sign_in_canceled') ||
            errMsg.contains('canceled') ||
            errMsg.contains('cancelled') ||
            errMsg.contains('web-context-cancelled')) {
          return; // User dismissed picker
        }
        _showError('Google sign-in error: $errMsg');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.error, content: Text(message)),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _successGreen, content: Text(message)),
    );
  }

  void _handleBackNavigation() {
    if (_screenState == AuthScreenState.forgotPassword) {
      setState(() {
        _resetLinkSent = false;
        _screenState = AuthScreenState.signIn;
      });
    } else if (_screenState == AuthScreenState.signUp) {
      setState(() {
        _screenState = AuthScreenState.signIn;
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
        // 1. Top Navigation: White background, Career360 branding
        appBar: _buildAuthenticationHeader(),
        body: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2. Enterprise Hero Header
                _buildAuthHero(),

                // 3. Curved Overlapping Bottom Sheet (Full width, 36px top rounded corners)
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(36),
                        topRight: Radius.circular(36),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x180B347C),
                          blurRadius: 20,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Simple Text-Based Underline Tabs (Sign In / Sign Up)
                        if (_screenState == AuthScreenState.signIn ||
                            _screenState == AuthScreenState.signUp) ...[
                          _buildAuthTabs(
                            isSignIn: _screenState == AuthScreenState.signIn,
                          ),
                          const SizedBox(height: 24),
                        ],

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
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
                            key: ValueKey(_screenState),
                            child: _buildCurrentForm(),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // Terms & Privacy Footer: Strictly on one continuous line
                        _buildAuthLegalFooter(),
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

  /// Component 1: AuthenticationHeader (White background, back button, Career360 logo)
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
                  const Icon(Icons.work_rounded, color: _primaryBlue, size: 24),
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
                  color: Color(0xFF0A2351),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '360',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _primaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Component 2: AuthHero (Pure Enterprise Minimalist - Direction A)
  Widget _buildAuthHero() {
    String badgeText = 'Verified Candidate Portal';
    IconData badgeIcon = Icons.shield_outlined;
    String heading = 'Welcome Back';
    String description =
        'Sign in to your Career360 account to continue your journey.';

    if (_screenState == AuthScreenState.signUp) {
      badgeText = 'Candidate Registration';
      badgeIcon = Icons.person_add_alt_1_outlined;
      heading = 'Create Your Account';
      description = 'Join Career360 and take the next step in your career.';
    } else if (_screenState == AuthScreenState.forgotPassword) {
      badgeText = 'Account Security';
      badgeIcon = Icons.lock_reset_rounded;
      heading = 'Forgot Password?';
      description = 'Enter your email address and we\'ll send you a link to reset your password.';
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_deepNavy, _secondaryBlue],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 68),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Column(
          key: ValueKey(_screenState),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Status Chip (Stripe / Apple Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(badgeIcon, size: 13, color: const Color(0xFF93C5FD)),
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
            const SizedBox(height: 14),

            // Authoritative Heading
            Text(
              heading,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE0E7FF),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Component 3: Simple Text-Based Underline Tabs (Sign In / Sign Up)
  Widget _buildAuthTabs({required bool isSignIn}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                scaleDown: 0.97,
                onPressed: () =>
                    setState(() => _screenState = AuthScreenState.signIn),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: isSignIn
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSignIn ? _primaryBlue : _secondaryText,
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
                onPressed: () =>
                    setState(() => _screenState = AuthScreenState.signUp),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: !isSignIn
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: !isSignIn ? _primaryBlue : _secondaryText,
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
            // Thin full-width baseline divider
            Container(height: 1.5, color: _dividerColor),
            // Blue underline indicator below the active tab
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: isSignIn
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  height: 3.0,
                  decoration: BoxDecoration(
                    color: _primaryBlue,
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
    if (_screenState == AuthScreenState.signIn) {
      return _buildSignInForm();
    } else if (_screenState == AuthScreenState.signUp) {
      return _buildSignUpForm();
    } else {
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
        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _signInEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _signInPasswordController,
          hint: 'Enter your password',
          obscureText: _obscureSignInPassword,
          onToggleVisibility: () =>
              setState(() => _obscureSignInPassword = !_obscureSignInPassword),
        ),
        const SizedBox(height: 12),

        // Remember me & Forgot Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: _primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(color: _inputBorder, width: 1.4),
                      onChanged: (val) =>
                          setState(() => _rememberMe = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Remember me',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF344054),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            BouncyButton(
              scaleDown: 0.95,
              onPressed: () {
                setState(() {
                  _forgotEmailController.text = _signInEmailController.text;
                  _resetLinkSent = false;
                  _screenState = AuthScreenState.forgotPassword;
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Primary Button
        _buildPrimaryButton(label: 'Sign In  ➔', onPressed: _handleSignIn),
        const SizedBox(height: 20),

        _buildDivider('or'),
        const SizedBox(height: 18),

        // Google Sign-In Button
        _buildGoogleSignInButton(),
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
        _buildFieldLabel('Full Name'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _signUpNameController,
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Email Address'),
        const SizedBox(height: 6),
        _buildFormInput(
          controller: _signUpEmailController,
          hint: 'Enter your email address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        _buildFieldLabel('Password'),
        const SizedBox(height: 6),
        _buildPasswordInput(
          controller: _signUpPasswordController,
          hint: 'Create a password',
          obscureText: _obscureSignUpPassword,
          onToggleVisibility: () =>
              setState(() => _obscureSignUpPassword = !_obscureSignUpPassword),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use at least 8 characters with a mix of letters, numbers and symbols.',
          style: TextStyle(fontSize: 11.5, color: _secondaryText, height: 1.3),
        ),
        const SizedBox(height: 22),

        // Primary Button
        _buildPrimaryButton(
          label: 'Create Account & Send OTP  ➔',
          onPressed: _handleInitiateSignUp,
        ),
        const SizedBox(height: 20),

        _buildDivider('or'),
        const SizedBox(height: 18),

        // Google Sign-In Button
        _buildGoogleSignInButton(),
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
        _buildFormInput(
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
              borderRadius: BorderRadius.circular(_inputRadius),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
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

        const SizedBox(height: 22),

        Center(
          child: BouncyButton(
            scaleDown: 0.95,
            onPressed: () {
              setState(() {
                _resetLinkSent = false;
                _screenState = AuthScreenState.signIn;
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
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
        ),
      ],
    );
  }

  // --- Shared Design Components ---

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

  /// Component 4: FormInput (56px Height, 10px Radius)
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
          hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF98A2B3)),
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
            borderSide: const BorderSide(color: _primaryBlue, width: 1.8),
          ),
        ),
      ),
    );
  }

  /// Component 5: PasswordInput (52px Height, Show/Hide Visibility Toggle)
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
          hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF98A2B3)),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: _secondaryText,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.remove_red_eye_outlined,
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
            borderSide: const BorderSide(color: _primaryBlue, width: 1.8),
          ),
        ),
      ),
    );
  }

  /// Component 6: PrimaryButton (Visual Click Color Animation, 52px Height, 10px Radius, Electric Blue #155EEF)
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final bool isEnabled = !_isLoading;
    return BouncyButton(
      onPressed: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(_inputRadius),
      pressOverlayColor: const Color(0xFF0C3E9E).withValues(alpha: 0.35),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: _buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isEnabled
              ? _primaryBlue
              : _primaryBlue.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(_inputRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.30),
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
              : Text(
                  label,
                  key: ValueKey(label),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  /// Component 7: GoogleSignInButton (Visual Click Color Animation, 52px Height, Neutral Border #D0D5DD)
  Widget _buildGoogleSignInButton() {
    final bool isEnabled = !_isLoading && !_isGoogleLoading;
    return BouncyButton(
      onPressed: isEnabled ? _handleGoogleSignIn : null,
      borderRadius: BorderRadius.circular(_inputRadius),
      pressOverlayColor: const Color(0xFF155EEF).withValues(alpha: 0.10),
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
                            _primaryBlue,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Connecting to Google...',
                        style: TextStyle(
                          fontSize: 15.0,
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
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 15.5,
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

  /// Component 8: AuthLegalFooter (Single Continuous Line)
  Widget _buildAuthLegalFooter() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 15, color: _primaryBlue),
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
                  ),
                  recognizer: _termsRecognizer,
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Privacy Policy.',
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.w600,
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

  Widget _buildDivider(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEAECF0), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _secondaryText,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _dividerColor, thickness: 1)),
      ],
    );
  }
}
