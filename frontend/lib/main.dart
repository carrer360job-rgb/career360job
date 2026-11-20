import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/responsive/responsive_layout.dart';
import 'core/services/candidate_photo_service.dart';
import 'core/services/employer_service.dart';
import 'core/services/employer_api_service.dart';
import 'core/services/platform_content_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/widgets/bouncy_button.dart';
import 'data/models/job_model.dart';
import 'data/models/employer_profile.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/candidate/candidate_guidelines_screen.dart';
import 'features/candidate/job_detail_screen.dart';
import 'features/employer/employer_guidelines_screen.dart';
import 'features/employer/employer_login_screen.dart';
import 'features/auth/candidate_login_screen.dart';
import 'features/auth/password_recovery_completion_screen.dart';
import 'features/candidate/candidate_onboarding_wizard_screen.dart';
import 'features/employer/employer_registration_screen.dart';
import 'features/employer/employer_workspace_screen.dart';
import 'features/legal/privacy_policy_screen.dart';
import 'features/notifications/notification_center_screen.dart';
import 'core/services/supabase_service.dart';
import 'core/services/app_auth_bridge.dart';
import 'core/services/supabase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Career360Bootstrap());
}

class Career360Bootstrap extends StatefulWidget {
  const Career360Bootstrap({super.key});

  @override
  State<Career360Bootstrap> createState() => _Career360BootstrapState();
}

class _Career360BootstrapState extends State<Career360Bootstrap> {
  late final Future<void> _bootstrapInitialization;

  @override
  void initState() {
    super.initState();
    _bootstrapInitialization = _initApp();
  }

  Future<void> _initApp() async {
    final stopwatch = Stopwatch()..start();
    try {
      await SupabaseService.initialize();
      await SupabaseAuthService.restoreRecoveryState();
      await SupabaseAuthService.restoreSuspensionNotice();
    } catch (e) {
      debugPrint('[Supabase Initialization Notice] $e');
    }
    unawaited(PushNotificationService.instance.initialize());
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1200) {
      await Future<void>.delayed(Duration(milliseconds: 1200 - elapsed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SessionLoadingScreen(),
          );
        }
        return const Career360App();
      },
    );
  }
}

typedef FirebaseBootstrap = Career360Bootstrap;

class FirebaseConfigurationFailure extends StatelessWidget {
  final String error;

  const FirebaseConfigurationFailure({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 40,
                    color: Color(0xFF155EEF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Career360 could not connect to its services',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Firebase is not configured for this platform. Please try again later.',
                    textAlign: TextAlign.center,
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    SelectableText(error, textAlign: TextAlign.center),
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

enum AppUserRole { candidate, employer, admin }

class Career360App extends StatefulWidget {
  final Stream<dynamic>? authChanges;

  const Career360App({super.key, this.authChanges});

  @override
  State<Career360App> createState() => _Career360AppState();
}

class _Career360AppState extends State<Career360App> {
  bool _showCandidateGuidelines = false;
  bool _showCandidateLogin = false;
  bool _showEmployerGuidelines = false;
  bool _showEmployerLogin = false;
  AppUserRole? _currentRole;
  int _sessionGeneration = 0;

  Future<void> _retrySessionStreams() async {
    if (mounted) setState(() => _sessionGeneration++);
    try {
      final user = AppAuthBridge.currentUser;
      await user?.reload();
      await user?.getIdToken(true);
    } catch (error) {
      debugPrint('[Session retry] Firebase refresh failed: $error');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  void _onRoleSelected(AppUserRole role) {
    if (role == AppUserRole.candidate) {
      setState(() {
        _currentRole = role;
        _showCandidateGuidelines = true;
      });
    } else if (role == AppUserRole.employer) {
      setState(() {
        _currentRole = role;
        _showEmployerGuidelines = true;
      });
    }
  }

  void _onEmployerGuidelinesAccepted() {
    setState(() {
      _showEmployerGuidelines = false;
      _showEmployerLogin = true;
    });
  }

  void _onEmployerGuidelinesBack() {
    setState(() {
      _showEmployerGuidelines = false;
      _currentRole = null;
    });
  }

  void _onEmployerLoginBack() {
    setState(() {
      _showEmployerLogin = false;
      _showEmployerGuidelines = true;
    });
  }

  void _onCandidateGuidelinesAccepted() {
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = true;
    });
  }

  void _onCandidateGuidelinesBack() {
    setState(() {
      _showCandidateGuidelines = false;
      _currentRole = null;
    });
  }

  void _onCandidateLoginBack() {
    setState(() {
      _showCandidateLogin = false;
      _showCandidateGuidelines = true;
    });
  }

  Future<void> _onCandidateOnboardingBack() async {
    setState(() {
      _showCandidateGuidelines = true;
      _showCandidateLogin = false;
      _showEmployerGuidelines = false;
      _showEmployerLogin = false;
      _currentRole = null;
    });
    await SupabaseService.client.auth.signOut();
  }

  Future<void> _signOutToRoleSelection() async {
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = false;
      _showEmployerGuidelines = false;
      _showEmployerLogin = false;
      _currentRole = null;
    });
    await SupabaseService.client.auth.signOut();
  }

  Future<void> _retrySuspendedSignIn() async {
    try {
      await SupabaseService.client.auth.signOut();
    } catch (error) {
      debugPrint('[Suspended account sign-out] $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = true;
      _showEmployerGuidelines = false;
      _showEmployerLogin = false;
      _currentRole = AppUserRole.candidate;
    });
    await SupabaseAuthService.clearSuspensionNotice();
  }

  void _resetToRoleSelection() {
    setState(() {
      _showCandidateGuidelines = false;
      _showCandidateLogin = false;
      _showEmployerGuidelines = false;
      _showEmployerLogin = false;
      _currentRole = null;
    });
  }

  Widget _buildCurrentScreen() {
    if (_showCandidateGuidelines) {
      return CandidateGuidelinesScreen(
        key: const ValueKey('guidelines_screen'),
        onAccepted: _onCandidateGuidelinesAccepted,
        onBack: _onCandidateGuidelinesBack,
      );
    }
    if (_showCandidateLogin) {
      return CandidateLoginScreen(
        key: const ValueKey('login_screen'),
        onBack: _onCandidateLoginBack,
      );
    }
    if (_showEmployerGuidelines) {
      return EmployerGuidelinesScreen(
        key: const ValueKey('employer_guidelines_screen'),
        onAccepted: _onEmployerGuidelinesAccepted,
        onBack: _onEmployerGuidelinesBack,
      );
    }
    if (_showEmployerLogin) {
      return EmployerLoginScreen(
        key: const ValueKey('employer_login_screen'),
        onBack: _onEmployerLoginBack,
      );
    }
    if (_currentRole == null) {
      return RoleSelectionScreen(
        key: const ValueKey('role_selection_screen'),
        onSelectRole: _onRoleSelected,
      );
    }
    return MainShellScreen(
      key: ValueKey('main_shell_${_currentRole!.name}'),
      currentRole: _currentRole!,
      onRoleChanged: _onRoleSelected,
      onSwitchRoleRequested: _resetToRoleSelection,
      onSignOutRequested: _resetToRoleSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Career360 — Job Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<bool>(
        valueListenable: SupabaseAuthService.suspensionNotice,
        builder: (context, isSuspended, _) {
          if (isSuspended) {
            return AccountAccessUnavailableScreen(
              status: 'SUSPENDED',
              onRetryLogin: () => unawaited(_retrySuspendedSignIn()),
            );
          }
          return ValueListenableBuilder<bool>(
            valueListenable: SupabaseAuthService.recoveryVerified,
            builder: (context, recoveryVerified, _) {
              if (recoveryVerified) {
                return PasswordRecoveryCompletionScreen(
                  role:
                      SupabaseAuthService.recoveryRole ??
                      PasswordRecoveryRole.candidate,
                );
              }
              return StreamBuilder<dynamic>(
                key: ValueKey('auth_stream_$_sessionGeneration'),
                stream: widget.authChanges ?? AppAuthBridge.authStateChanges,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('[Auth state stream] ${snapshot.error}');
                    return AuthStateLoadFailure(
                      error: snapshot.error,
                      onRetry: _retrySessionStreams,
                      onSignOut: _signOutToRoleSelection,
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const SessionLoadingScreen();
                  }

                  final user = snapshot.data;
                  if (user != null) {
                    return AccountSessionGate(
                      key: ValueKey(
                        'account_session_${user.uid}_$_sessionGeneration',
                      ),
                      user: user,
                      requestedRole: _currentRole,
                      onRoleSelected: _onRoleSelected,
                      onBackToLogin: _onCandidateOnboardingBack,
                      onRoleChanged: _onRoleSelected,
                      onSwitchRoleRequested: _signOutToRoleSelection,
                      onSignOutRequested: _signOutToRoleSelection,
                      onRetry: _retrySessionStreams,
                    );
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    reverseDuration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slide =
                          Tween<Offset>(
                            begin: const Offset(0.04, 0.0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );
                      return SlideTransition(
                        position: slide,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: _buildCurrentScreen(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class AccountSessionGate extends StatelessWidget {
  final dynamic user;
  final AppUserRole? requestedRole;
  final ValueChanged<AppUserRole> onRoleSelected;
  final Future<void> Function() onBackToLogin;
  final ValueChanged<AppUserRole> onRoleChanged;
  final VoidCallback onSwitchRoleRequested;
  final VoidCallback onSignOutRequested;
  final Future<void> Function() onRetry;

  const AccountSessionGate({
    super.key,
    required this.user,
    required this.requestedRole,
    required this.onRoleSelected,
    required this.onBackToLogin,
    required this.onRoleChanged,
    required this.onSwitchRoleRequested,
    required this.onSignOutRequested,
    required this.onRetry,
  });

  Stream<List<Map<String, dynamic>>> _streamAccountProfile(String uid) async* {
    try {
      if (user.emailVerified != true) {
        yield [];
        return;
      }
      if (SupabaseService.client.auth.currentUser?.id != uid) {
        throw StateError('Sign in again to load your account.');
      }
      final row = await SupabaseAuthService().ensureAccountProfile(
        preferredRole: requestedRole?.name,
      );
      yield [row];
    } catch (e) {
      debugPrint('[Account role fetch notice] $e');
      rethrow;
    }

    try {
      yield* SupabaseService.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', uid);
    } catch (error) {
      debugPrint('[Profiles Realtime Notice] $error');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: _streamAccountProfile(user.uid),
        builder: (context, snapshot) {
          if (user.emailVerified != true) {
            return EmailVerificationRequiredScreen(user: user);
          }
          if (snapshot.hasError) {
            debugPrint('[Account role stream] ${snapshot.error}');
            return AuthStateLoadFailure(
              error: snapshot.error,
              onRetry: onRetry,
              onSignOut: () async => onSignOutRequested(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SessionLoadingScreen();
          }
          final rows = snapshot.data ?? const [];
          final storedRole = rows.isNotEmpty
              ? rows.first['role']?.toString().toLowerCase()
              : null;
          final unsupportedStoredRole = storedRole != null &&
              !{'candidate', 'employer', 'admin'}.contains(storedRole);
          if (unsupportedStoredRole) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'This account type is no longer supported in the app.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onSignOutRequested,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final selectedRole = storedRole == 'employer'
              ? AppUserRole.employer
              : storedRole == 'candidate'
              ? AppUserRole.candidate
              : storedRole == 'admin'
              ? AppUserRole.admin
              : requestedRole;
          final accountStatus = rows.isNotEmpty
              ? rows.first['status']?.toString().toUpperCase()
              : null;
          if (selectedRole == AppUserRole.candidate &&
              accountStatus != 'ACTIVE') {
            if (accountStatus == 'SUSPENDED' || accountStatus == 'BLOCKED') {
              unawaited(SupabaseAuthService.showSuspensionNotice());
            }
            return AccountAccessUnavailableScreen(
              status: accountStatus,
              onRetryLogin: onSignOutRequested,
            );
          }
          if (selectedRole == null) {
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: RoleSelectionScreen(onSelectRole: onRoleSelected),
                    ),
                    TextButton(
                      onPressed: onSignOutRequested,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (storedRole != null &&
              requestedRole != null &&
              requestedRole != selectedRole) {
            final correct = selectedRole == AppUserRole.employer
                ? 'employer'
                : selectedRole == AppUserRole.admin
                ? 'admin'
                : 'job seeker';
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_circle_outlined,
                        size: 48,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This email belongs to a $correct account.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign out and continue with a separate email for this role.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onSignOutRequested,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (selectedRole == AppUserRole.admin) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Use the web dashboard for this admin account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onSignOutRequested,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (selectedRole == AppUserRole.employer) {
            return EmployerSessionGate(
              user: user,
              accountStatus: accountStatus,
              onSignOut: onSignOutRequested,
              onRetry: onRetry,
            );
          }
          return CandidateSessionGate(
            user: user,
            onBackToLogin: onBackToLogin,
            onRoleChanged: onRoleChanged,
            onSwitchRoleRequested: onSwitchRoleRequested,
            onSignOutRequested: onSignOutRequested,
            onRetry: onRetry,
          );
        },
      );
}

class AccountAccessUnavailableScreen extends StatelessWidget {
  final String? status;
  final VoidCallback onRetryLogin;

  const AccountAccessUnavailableScreen({
    super.key,
    required this.status,
    required this.onRetryLogin,
  });

  @override
  Widget build(BuildContext context) {
    final title = status == 'SUSPENDED'
        ? 'Your account is suspended'
        : status == 'BLOCKED'
        ? 'Account blocked'
        : 'Account access unavailable';
    final message = status == 'SUSPENDED' || status == 'BLOCKED'
        ? 'You can’t use the job seeker portal right now. Contact Career360 support if you need help.'
        : 'We couldn’t confirm that your account is active. Try again or sign out and sign in again.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'SUSPENDED' || status == 'BLOCKED'
                        ? Icons.lock_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Need help or have a question?',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => launchUrl(
                            Uri(
                              scheme: 'mailto',
                              path: AppConstants.supportEmail,
                              queryParameters: {
                                'subject': 'Career360 account access',
                              },
                            ),
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              AppConstants.supportEmail,
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: onRetryLogin,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmployerSessionGate extends StatefulWidget {
  final dynamic user;
  final String? accountStatus;
  final VoidCallback onSignOut;
  final Future<void> Function() onRetry;

  const EmployerSessionGate({
    super.key,
    required this.user,
    required this.accountStatus,
    required this.onSignOut,
    required this.onRetry,
  });

  @override
  State<EmployerSessionGate> createState() => _EmployerSessionGateState();
}

class _EmployerSessionGateState extends State<EmployerSessionGate> {
  late Stream<EmployerProfile?> _profileStream;
  bool _keepRegistrationVisible = false;

  @override
  void initState() {
    super.initState();
    _profileStream = EmployerService().watchProfile(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.emailVerified != true) {
      return EmailVerificationRequiredScreen(user: widget.user);
    }
    return StreamBuilder<EmployerProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[Employer profile stream] ${snapshot.error}');
          return AuthStateLoadFailure(
            error: snapshot.error,
            onRetry: widget.onRetry,
            onSignOut: () async => widget.onSignOut(),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SessionLoadingScreen();
        }
        final profile = snapshot.data;
        if (profile == null || _keepRegistrationVisible) {
          return EmployerRegistrationScreen(
            onSignOut: widget.onSignOut,
            onSubmissionStarted: () {
              if (mounted) setState(() => _keepRegistrationVisible = true);
            },
            onSubmissionFailed: () {
              if (mounted) setState(() => _keepRegistrationVisible = false);
            },
            onFinished: () {
              if (mounted) {
                setState(() {
                  _keepRegistrationVisible = false;
                  _profileStream = EmployerService().watchProfile(
                    widget.user.uid,
                  );
                });
              }
            },
          );
        }
        if (!profile.isApproved || widget.accountStatus != 'ACTIVE') {
          return EmployerReviewScreen(
            profile: profile,
            accountSuspended:
                widget.accountStatus == 'SUSPENDED' ||
                widget.accountStatus == 'BLOCKED',
            onRefresh: () {
              if (mounted) {
                setState(() {
                  _profileStream = EmployerService().watchProfile(
                    widget.user.uid,
                  );
                });
              }
            },
            onSignOut: widget.onSignOut,
          );
        }
        return EmployerWorkspaceScreen(
          profile: profile,
          onSignOut: widget.onSignOut,
          onProfileUpdated: () {
            if (mounted) {
              setState(() {
                _profileStream = EmployerService().watchProfile(
                  widget.user.uid,
                );
              });
            }
          },
        );
      },
    );
  }
}

class EmployerReviewScreen extends StatelessWidget {
  final EmployerProfile profile;
  final bool accountSuspended;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

  const EmployerReviewScreen({
    super.key,
    required this.profile,
    this.accountSuspended = false,
    required this.onRefresh,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final rejected = profile.reviewState == 'rejected';
    final suspended = accountSuspended || profile.reviewState == 'suspended';
    final title = suspended
        ? 'Company access suspended'
        : rejected
        ? 'Company review unsuccessful'
        : 'Approval pending';
    final message = suspended
        ? 'Your company cannot use the employer portal right now.'
        : rejected
        ? 'Your company was not approved for the employer portal.'
        : 'Your company details have been submitted. An admin will review them before you can use the employer portal.';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rejected || suspended
                        ? Icons.business_outlined
                        : Icons.hourglass_top_rounded,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.companyName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  if ((rejected || suspended) &&
                      profile.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Reason: ${profile.rejectionReason}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Questions or help?'),
                  TextButton(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'mailto', path: AppConstants.supportEmail),
                    ),
                    child: const Text(AppConstants.supportEmail),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh status'),
                  ),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CandidateSessionGate extends StatefulWidget {
  final dynamic user;
  final Future<void> Function() onBackToLogin;
  final ValueChanged<AppUserRole> onRoleChanged;
  final VoidCallback onSwitchRoleRequested;
  final VoidCallback onSignOutRequested;
  final Future<void> Function() onRetry;
  final Stream<Map<String, dynamic>?> Function(String uid)?
  profileStreamFactory;

  const CandidateSessionGate({
    super.key,
    required this.user,
    required this.onBackToLogin,
    required this.onRoleChanged,
    required this.onSwitchRoleRequested,
    required this.onSignOutRequested,
    required this.onRetry,
    this.profileStreamFactory,
  });

  @override
  State<CandidateSessionGate> createState() => _CandidateSessionGateState();
}

class _CandidateSessionGateState extends State<CandidateSessionGate> {
  late Stream<Map<String, dynamic>?> _profileStream;

  Stream<Map<String, dynamic>?> _createProfileStream() =>
      widget.profileStreamFactory?.call(widget.user.uid) ??
      SupabaseService().streamCandidateProfile(widget.user.uid);

  @override
  void initState() {
    super.initState();
    _profileStream = _createProfileStream();
  }

  @override
  void didUpdateWidget(CandidateSessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.profileStreamFactory != widget.profileStreamFactory) {
      _profileStream = _createProfileStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.emailVerified != true) {
      return EmailVerificationRequiredScreen(user: widget.user);
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[Candidate profile stream] ${snapshot.error}');
          return AuthStateLoadFailure(
            error: snapshot.error,
            onRetry: widget.onRetry,
            onSignOut: () async => widget.onSignOutRequested(),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SessionLoadingScreen();
        }

        final profile = snapshot.data;
        final onboardingComplete = profile?['onboarding_completed_at'] != null;
        if (!onboardingComplete) {
          return CandidateOnboardingWizardScreen(
            key: ValueKey('candidate_onboarding_${widget.user.uid}'),
            onFinish: () => unawaited(widget.onRetry()),
            onBackToLogin: () => unawaited(widget.onBackToLogin()),
            initialProfile: profile,
          );
        }

        return MainShellScreen(
          key: ValueKey('main_shell_${widget.user.uid}'),
          currentRole: AppUserRole.candidate,
          onRoleChanged: widget.onRoleChanged,
          onSwitchRoleRequested: widget.onSwitchRoleRequested,
          onSignOutRequested: widget.onSignOutRequested,
        );
      },
    );
  }
}

class SessionLoadingScreen extends StatefulWidget {
  const SessionLoadingScreen({super.key});

  @override
  State<SessionLoadingScreen> createState() => _SessionLoadingScreenState();
}

class _SessionLoadingScreenState extends State<SessionLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            right: -80,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryLight.withValues(alpha: 0.8),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: AppTheme.primaryLightBorder,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.16),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/career360_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Career',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '360',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Find Your Dream Job',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Explore thousands of opportunities in Tamil Nadu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Clean branded loading text (matching test specification)
                      const Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryLightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppTheme.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Verified Tamil Nadu Job Platform',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthStateLoadFailure extends StatelessWidget {
  final Object? error;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onSignOut;

  const AuthStateLoadFailure({
    super.key,
    this.error,
    this.onRetry,
    this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _AuthLoadFailureContent(
            error: error,
            onRetry: onRetry,
            onSignOut: onSignOut,
          ),
        ),
      ),
    );
  }
}

class _AuthLoadFailureContent extends StatefulWidget {
  final Object? error;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onSignOut;

  const _AuthLoadFailureContent({this.error, this.onRetry, this.onSignOut});

  @override
  State<_AuthLoadFailureContent> createState() =>
      _AuthLoadFailureContentState();
}

class _AuthLoadFailureContentState extends State<_AuthLoadFailureContent> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    try {
      if (widget.onRetry != null) {
        await widget.onRetry!();
      } else {
        final user = AppAuthBridge.currentUser;
        await user?.reload();
        await user?.getIdToken(true);
      }
    } catch (error) {
      debugPrint('[Session retry] $error');
    }
    if (mounted) setState(() => _isRetrying = false);
  }

  String get _failureMessage {
    final error = widget.error;
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Firebase denied access to this account. Check that the latest Firestore rules are published and that this account has the correct role.';
        case 'unavailable':
        case 'deadline-exceeded':
          return 'Career360 cannot reach Firebase right now. Check the phone’s internet connection and try again.';
        case 'failed-precondition':
          return 'The Firebase database setup is incomplete. Check the Firestore indexes and configuration.';
        case 'unauthenticated':
          return 'Your sign-in session expired. Retry to refresh it, or sign in again.';
      }
    }
    return 'We could not load your account right now. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_failureMessage, textAlign: TextAlign.center),
        if (kDebugMode && widget.error != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            widget.error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _isRetrying ? null : _retry,
          child: _isRetrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Retry'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _isRetrying
              ? null
              : () async {
                  try {
                    if (widget.onSignOut != null) {
                      await widget.onSignOut!();
                    } else {
                      await AppAuthBridge.signOut();
                    }
                  } catch (error) {
                    debugPrint('[Session sign out] $error');
                  }
                },
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}

class EmailVerificationRequiredScreen extends StatefulWidget {
  final dynamic user;

  const EmailVerificationRequiredScreen({super.key, required this.user});

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  bool _isSending = false;
  String? _message;

  Future<void> _sendVerificationEmail() async {
    setState(() => _isSending = true);
    try {
      await widget.user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message =
            'Verification email sent. Open the link, then tap I verified.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message = 'Could not send a verification email.';
      });
    }
  }

  Future<void> _refreshVerificationStatus() async {
    setState(() => _isSending = true);
    try {
      final response = await SupabaseService.client.auth.getUser();
      final isVerified = response.user?.emailConfirmedAt != null;
      if (isVerified) await SupabaseService.client.auth.refreshSession();
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message = isVerified ? 'Email verified. Loading your profile...' : 'The email is not verified yet. Open the link from your inbox and retry.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _message = 'Could not check verification status.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 42,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verify your email to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification link to ${widget.user.email ?? 'your email address'}.',
                  textAlign: TextAlign.center,
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isSending ? null : _refreshVerificationStatus,
                  child: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I verified my email'),
                ),
                TextButton(
                  onPressed: _isSending ? null : _sendVerificationEmail,
                  child: const Text('Resend verification email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final AppUserRole currentRole;
  final ValueChanged<AppUserRole> onRoleChanged;
  final VoidCallback onSwitchRoleRequested;
  final VoidCallback onSignOutRequested;

  const MainShellScreen({
    super.key,
    required this.currentRole,
    required this.onRoleChanged,
    required this.onSwitchRoleRequested,
    required this.onSignOutRequested,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  final SupabaseService _firestoreService = SupabaseService();
  late Stream<List<JobModel>> _jobsStream;
  final CandidatePhotoService _candidatePhotoService = CandidatePhotoService();
  final PlatformContentService _platformContentService =
      PlatformContentService();
  List<Map<String, dynamic>> _managedCategories = const [];
  String get _currentUid => AppAuthBridge.currentUser?.uid ?? 'guest_candidate';

  int _selectedTabIndex = 0;
  String _selectedLocation = 'All Locations';
  String? _selectedCategory;
  String _searchQuery = '';
  final Set<String> _savedJobIds = {};
  final Set<String> _appliedJobIds = {};
  bool _savedJobsReady = false;
  bool _savedJobsLoadFailed = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  Timer? _searchDebounce;
  Timer? _jobsRefreshTimer;

  // Employer Post Job Controllers
  final TextEditingController _postTitleController = TextEditingController();
  final TextEditingController _postCompanyController = TextEditingController();
  final TextEditingController _postSalaryController = TextEditingController();
  final TextEditingController _postVacanciesController =
      TextEditingController();
  final TextEditingController _postDescController = TextEditingController();
  String _postCategory = 'IT & Software';
  String _postLocation = 'Chennai';
  String _postWorkMode = 'Hybrid';
  bool _isPostingJob = false;
  bool _isUploadingPhoto = false;

  StreamSubscription<Set<String>>? _savedSub;
  StreamSubscription<Set<String>>? _appliedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _jobsStream = _firestoreService.streamJobs();
    _jobsRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshJobs(),
    );
    unawaited(_loadManagedCategories());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(PushNotificationService.instance.registerAfterPortalEntry());
      }
    });
    _subscribeSavedJobs();
    _appliedSub = _firestoreService.streamAppliedJobIds(_currentUid).listen((
      ids,
    ) {
      if (mounted) {
        setState(
          () => _appliedJobIds
            ..clear()
            ..addAll(ids),
        );
      }
    });
  }

  void _subscribeSavedJobs() {
    unawaited(_savedSub?.cancel());
    setState(() {
      _savedJobsReady = false;
      _savedJobsLoadFailed = false;
    });
    _savedSub = _firestoreService.streamSavedJobIds(_currentUid).listen(
      (ids) {
        if (!mounted) return;
        setState(() {
          _savedJobsReady = true;
          _savedJobsLoadFailed = false;
          _savedJobIds
            ..clear()
            ..addAll(ids);
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[Saved jobs] $error');
        if (mounted) setState(() => _savedJobsLoadFailed = true);
      },
    );
  }

  Future<void> _loadManagedCategories() async {
    try {
      final categories = await _platformContentService.list('category');
      if (mounted) {
        setState(() {
          if (categories.isNotEmpty) {
            _managedCategories = categories;
          }
        });
      }
    } catch (_) {
      // Keep the bundled categories available when the content service is offline.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _jobsRefreshTimer?.cancel();
    _savedSub?.cancel();
    _appliedSub?.cancel();
    _searchController.dispose();
    _feedScrollController.dispose();
    _postTitleController.dispose();
    _postCompanyController.dispose();
    _postSalaryController.dispose();
    _postVacanciesController.dispose();
    _postDescController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshJobs();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _refreshJobs() {
    if (!mounted) return;
    setState(() => _jobsStream = _firestoreService.streamJobs());
  }

  static bool _isCategoryMatch(String jobCategory, String filterCategory) {
    final job = jobCategory.trim().toLowerCase();
    final filter = filterCategory.trim().toLowerCase();
    if (filter.isEmpty || filter == 'all') return true;
    if (job == filter) return true;
    if (job.contains(filter) || filter.contains(job)) return true;

    // IT & Software / Information Technology
    final filterIsTech = filter.contains('it') ||
        filter.contains('software') ||
        filter.contains('information technology') ||
        filter.contains('tech') ||
        filter.contains('developer') ||
        filter.contains('computer');
    final jobIsTech = job.contains('it') ||
        job.contains('software') ||
        job.contains('information technology') ||
        job.contains('tech') ||
        job.contains('developer') ||
        job.contains('computer');
    if (filterIsTech && jobIsTech) return true;

    // Manufacturing & Production
    final filterIsMfg = filter.contains('manufactur') ||
        filter.contains('production') ||
        filter.contains('automobile') ||
        filter.contains('auto') ||
        filter.contains('textile') ||
        filter.contains('industrial') ||
        filter.contains('plant');
    final jobIsMfg = job.contains('manufactur') ||
        job.contains('production') ||
        job.contains('automobile') ||
        job.contains('auto') ||
        job.contains('textile') ||
        job.contains('industrial') ||
        job.contains('plant');
    if (filterIsMfg && jobIsMfg) return true;

    // Sales & Marketing
    final filterIsSales = filter.contains('sales') ||
        filter.contains('market') ||
        filter.contains('retail') ||
        filter.contains('commerce') ||
        filter.contains('advertising');
    final jobIsSales = job.contains('sales') ||
        job.contains('market') ||
        job.contains('retail') ||
        job.contains('commerce') ||
        job.contains('advertising');
    if (filterIsSales && jobIsSales) return true;

    // Finance & Banking
    final filterIsFinance = filter.contains('finan') ||
        filter.contains('bank') ||
        filter.contains('account') ||
        filter.contains('tax') ||
        filter.contains('audit');
    final jobIsFinance = job.contains('finan') ||
        job.contains('bank') ||
        job.contains('account') ||
        job.contains('tax') ||
        job.contains('audit');
    if (filterIsFinance && jobIsFinance) return true;

    // Healthcare & Medical
    final filterIsHealth = filter.contains('health') ||
        filter.contains('medic') ||
        filter.contains('pharma') ||
        filter.contains('clinic') ||
        filter.contains('hospital') ||
        filter.contains('nurse');
    final jobIsHealth = job.contains('health') ||
        job.contains('medic') ||
        job.contains('pharma') ||
        job.contains('clinic') ||
        job.contains('hospital') ||
        job.contains('nurse');
    if (filterIsHealth && jobIsHealth) return true;

    // Education & EdTech
    final filterIsEdu = filter.contains('educat') ||
        filter.contains('teach') ||
        filter.contains('tutor') ||
        filter.contains('school') ||
        filter.contains('academic');
    final jobIsEdu = job.contains('educat') ||
        job.contains('teach') ||
        job.contains('tutor') ||
        job.contains('school') ||
        job.contains('academic');
    if (filterIsEdu && jobIsEdu) return true;

    // Customer Care / Support / BPO
    final filterIsBpo = filter.contains('support') ||
        filter.contains('bpo') ||
        filter.contains('customer') ||
        filter.contains('call center') ||
        filter.contains('helpdesk');
    final jobIsBpo = job.contains('support') ||
        job.contains('bpo') ||
        job.contains('customer') ||
        job.contains('call center') ||
        job.contains('helpdesk');
    if (filterIsBpo && jobIsBpo) return true;

    // Logistics & Supply Chain
    final filterIsLogistics = filter.contains('logistic') ||
        filter.contains('supply') ||
        filter.contains('warehouse') ||
        filter.contains('delivery') ||
        filter.contains('transport');
    final jobIsLogistics = job.contains('logistic') ||
        job.contains('supply') ||
        job.contains('warehouse') ||
        job.contains('delivery') ||
        job.contains('transport');
    if (filterIsLogistics && jobIsLogistics) return true;

    // Hospitality & Tourism
    final filterIsHospitality = filter.contains('hospital') ||
        filter.contains('hotel') ||
        filter.contains('tour') ||
        filter.contains('restaurant') ||
        filter.contains('food');
    final jobIsHospitality = job.contains('hospital') ||
        job.contains('hotel') ||
        job.contains('tour') ||
        job.contains('restaurant') ||
        job.contains('food');
    if (filterIsHospitality && jobIsHospitality) return true;

    // Construction & Real Estate
    final filterIsConstruction = filter.contains('construct') ||
        filter.contains('real estate') ||
        filter.contains('civil') ||
        filter.contains('architect');
    final jobIsConstruction = job.contains('construct') ||
        job.contains('real estate') ||
        job.contains('civil') ||
        job.contains('architect');
    if (filterIsConstruction && jobIsConstruction) return true;

    return false;
  }

  List<JobModel> _filterCandidateJobs(List<JobModel> allJobs) {
    final query = _searchQuery.trim().toLowerCase();
    return allJobs.where((job) {
      if (!job.isOpen) return false;
      if (_selectedLocation != 'All Locations' &&
          !job.isStatewide &&
          !job.locationCity.toLowerCase().contains(_selectedLocation.toLowerCase())) {
        return false;
      }
      if (_selectedCategory != null &&
          !_isCategoryMatch(job.category, _selectedCategory!)) {
        return false;
      }
      if (query.isEmpty) return true;
      return job.title.toLowerCase().contains(query) ||
          job.companyName.toLowerCase().contains(query) ||
          job.locationCity.toLowerCase().contains(query) ||
          job.category.toLowerCase().contains(query) ||
          job.description.toLowerCase().contains(query);
    }).toList();
  }

  void _openCandidateSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = _searchController.text.trim();
      _selectedTabIndex = 1;
    });
  }

  Future<void> _toggleSaveJob(String id) async {
    final isSaved = _savedJobIds.contains(id);
    setState(() {
      if (isSaved) {
        _savedJobIds.remove(id);
      } else {
        _savedJobIds.add(id);
      }
    });
    bool saved;
    try {
      saved = await _firestoreService.toggleSaveJob(
        candidateUid: _currentUid,
        jobId: id,
        isSaved: isSaved,
      );
    } catch (error) {
      debugPrint('[Saved jobs] $error');
      saved = isSaved;
    }
    if (!mounted) return;
    if (saved == isSaved) {
      setState(() {
        if (isSaved) {
          _savedJobIds.add(id);
        } else {
          _savedJobIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update saved jobs. Try again.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.primaryDark,
        content: Text(
          !isSaved ? 'Job saved to bookmarks' : 'Job removed from bookmarks',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _showJobDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(
          job: job,
          candidateUid: _currentUid,
          isApplied: _appliedJobIds.contains(job.id),
          isSaved: _savedJobIds.contains(job.id),
          onApply: () => setState(() => _appliedJobIds.add(job.id)),
          onToggleSave: () => _toggleSaveJob(job.id),
          onReport: () => _reportJob(job),
        ),
      ),
    );
  }

  Future<void> _reportJob(JobModel job) async {
    final detailsController = TextEditingController();
    var reason = 'fraud';
    var message = '';
    final report = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report this job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(
                    value: 'fraud',
                    child: Text('Looks fraudulent'),
                  ),
                  DropdownMenuItem(
                    value: 'misleading',
                    child: Text('Misleading details'),
                  ),
                  DropdownMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate listing'),
                  ),
                  DropdownMenuItem(
                    value: 'inappropriate',
                    child: Text('Inappropriate content'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setDialogState(() {
                  reason = value ?? 'fraud';
                  message = '';
                }),
              ),
              if (reason == 'other')
                TextField(
                  controller: detailsController,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Tell us more'),
                ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reason == 'other' &&
                    detailsController.text.trim().length < 5) {
                  setDialogState(
                    () => message = 'Please add at least five characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'reason': reason,
                  'details': detailsController.text.trim(),
                });
              },
              child: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
    detailsController.dispose();
    if (report == null || !mounted) return;
    try {
      await _platformContentService.reportJob(
        job.id,
        report['reason']!,
        report['details']!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks. Your report was sent for review.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          bottom: true,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Jobs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedLocation = 'All Locations';
                              _selectedCategory = null;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            Navigator.pop(ctx);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('Reset All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    const Text(
                      'Preferred Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final locations = List<String>.from(AppConstants.jobLocations);
                        if (!locations.contains(_selectedLocation)) {
                          locations.insert(1, _selectedLocation);
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: locations.map((loc) {
                            final isSelected = _selectedLocation == loc;
                            return ChoiceChip(
                              label: Text(loc),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFFF8FAFC),
                              showCheckmark: isSelected,
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedLocation = loc;
                                });
                                setModalState(() {});
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Job Category',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children:
                          [
                            'All',
                            'IT & Software',
                            'Manufacturing',
                            'Sales & Marketing',
                            'Finance & Banking',
                            'Healthcare & Medical',
                            'Education & EdTech',
                            'Customer Support',
                            'Logistics & Operations',
                            'Hospitality & Tourism',
                            'Construction & Real Estate',
                          ].map((cat) {
                            final isSelected =
                                (_selectedCategory == cat) ||
                                (_selectedCategory == null && cat == 'All');
                            return ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFFF8FAFC),
                              showCheckmark: isSelected,
                              checkmarkColor: Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategory = cat == 'All' ? null : cat;
                                });
                                setModalState(() {});
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationCenterScreen(uid: AppAuthBridge.currentUser?.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return PopScope(
      canPop: _selectedTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedTabIndex != 0) {
          setState(() {
            _selectedTabIndex = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/career360_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: const [
                  Text(
                    'Career',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  Text(
                    '360',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: widget.currentRole == AppUserRole.candidate
              ? [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openNotifications,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  IconButton(
                    tooltip: 'Notifications',
                    icon: const Icon(Icons.notifications_none),
                    onPressed: _openNotifications,
                  ),
                  IconButton(
                    tooltip: 'Switch Mode',
                    icon: const Icon(Icons.swap_horiz, color: AppTheme.primary),
                    onPressed: widget.onSwitchRoleRequested,
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.primary,
                    ),
                    onPressed: widget.onSignOutRequested,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getRoleBadgeText(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
        ),
        body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
        bottomNavigationBar: isDesktop ? null : _buildMobileBottomNav(),
      ),
    );
  }

  String _getRoleBadgeText() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return 'Candidate';
      case AppUserRole.employer:
        return 'Recruiter ATS';
      case AppUserRole.admin:
        return 'Admin';
    }
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar Navigation
        Container(
          width: 260,
          color: AppTheme.primaryDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _getRoleHeader(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._getNavItems().asMap().entries.map((entry) {
                final int idx = entry.key;
                final Map<String, dynamic> item = entry.value;
                final bool isSelected = _selectedTabIndex == idx;
                return ListTile(
                  leading: Icon(
                    item['icon'] as IconData,
                    color: isSelected ? AppTheme.accent : Colors.white70,
                  ),
                  title: Text(
                    item['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  tileColor: isSelected
                      ? Colors.white.withValues(alpha: 0.1)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedTabIndex = idx;
                    });
                  },
                );
              }),
            ],
          ),
        ),
        // Main View
        Expanded(
          child: Container(
            color: AppTheme.background,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${widget.currentRole.name}_$_selectedTabIndex',
                    ),
                    child: _getActiveScreen(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey('${widget.currentRole.name}_$_selectedTabIndex'),
            child: _getActiveScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav() {
    final items = _getNavItems();
    return BottomNavigationBar(
      currentIndex: _selectedTabIndex,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: AppTheme.textSecondary,
      backgroundColor: Colors.white,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
      onTap: (idx) {
        setState(() {
          _selectedTabIndex = idx;
        });
      },
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon'] as IconData),
          label: item['shortLabel'] as String,
        );
      }).toList(),
    );
  }

  String _getRoleHeader() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return 'JOB SEEKER WORKSPACE';
      case AppUserRole.employer:
        return 'RECRUITER ATS DESK';
      case AppUserRole.admin:
        return 'ADMIN CONTROL PANEL';
    }
  }

  List<Map<String, dynamic>> _getNavItems() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        return [
          {
            'icon': Icons.home_filled,
            'label': 'Home Discovery',
            'shortLabel': 'Home',
          },
          {
            'icon': Icons.search,
            'label': 'Search Jobs',
            'shortLabel': 'Search',
          },
          {
            'icon': Icons.bookmark_outline,
            'label': 'Saved Jobs',
            'shortLabel': 'Saved',
          },
          {
            'icon': Icons.person_outline,
            'label': 'Candidate Profile',
            'shortLabel': 'Profile',
          },
        ];
      case AppUserRole.employer:
        return [
          {
            'icon': Icons.dashboard_outlined,
            'label': 'Dashboard & Quota',
            'shortLabel': 'Overview',
          },
          {
            'icon': Icons.post_add,
            'label': 'Post a Job',
            'shortLabel': 'Post Job',
          },
          {
            'icon': Icons.people_outline,
            'label': 'Candidate Applicants',
            'shortLabel': 'Applicants',
          },
        ];
      case AppUserRole.admin:
        return [
          {
            'icon': Icons.analytics_outlined,
            'label': 'Platform Analytics',
            'shortLabel': 'Stats',
          },
          {
            'icon': Icons.verified_user_outlined,
            'label': 'Verify Employers',
            'shortLabel': 'Verify',
          },
          {
            'icon': Icons.fact_check_outlined,
            'label': 'Job Moderation',
            'shortLabel': 'Moderate',
          },
        ];
    }
  }

  Widget _getActiveScreen() {
    switch (widget.currentRole) {
      case AppUserRole.candidate:
        if (_selectedTabIndex == 0) return _buildCandidateHomeFeed();
        if (_selectedTabIndex == 1) return _buildCandidateSearchScreen();
        if (_selectedTabIndex == 2) return _buildCandidateSavedScreen();
        return _buildCandidateProfileScreen();

      case AppUserRole.employer:
        if (_selectedTabIndex == 0) return _buildEmployerOverview();
        if (_selectedTabIndex == 1) return _buildEmployerPostJob();
        return _buildEmployerApplicants();

      case AppUserRole.admin:
        return _buildAdminPanel();
    }
  }

  // --- CANDIDATE HOME FEED ---
  Widget _buildCandidateHomeFeed() {
    return StreamBuilder<List<JobModel>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        final jobs = _filterCandidateJobs(snapshot.data ?? []);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        return StreamBuilder<Map<String, dynamic>?>(
          stream: _firestoreService.streamCandidateProfile(_currentUid),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            final fullName =
                (profile?['fullName'] as String?)?.trim().isNotEmpty == true
                ? (profile!['fullName'] as String).trim()
                : AppAuthBridge.currentUser?.displayName ?? 'Candidate';
            final firstName = fullName.split(RegExp(r'\s+')).first;
            final preferredRoles = profile?['preferredJobTitles'];
            final needsPreferences =
                profile != null &&
                (preferredRoles is! List || preferredRoles.isEmpty);
            final hasActiveFilters =
                _selectedCategory != null ||
                _selectedLocation != 'All Locations' ||
                _searchQuery.trim().isNotEmpty;

            return ListView(
              controller: _feedScrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Welcome back, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Find your next opportunity',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: _onSearchChanged,
                          onSubmitted: (_) => _openCandidateSearch(),
                          decoration: InputDecoration(
                            hintText: 'Search jobs, companies, locations',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: AppTheme.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: AppTheme.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: const BorderSide(
                                color: AppTheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filledTonal(
                        tooltip: 'Filter jobs',
                        onPressed: _showFilterModal,
                        icon: const Icon(Icons.tune_rounded),
                        style: IconButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: AppTheme.primary,
                    ),
                    label: Text(
                      _selectedLocation == 'All Locations'
                          ? 'All locations'
                          : _selectedLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: _showFilterModal,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.border),
                    labelStyle: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (needsPreferences) ...[
                  const SizedBox(height: 12),
                  _buildPreferencesPrompt(),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Browse categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showFilterModal,
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCategoryGrid(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedCategory == null
                            ? 'Latest jobs'
                            : '${_selectedCategory!} jobs',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openCandidateSearch,
                      child: const Text('See all'),
                    ),
                  ],
                ),
                if (hasActiveFilters)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        _searchDebounce?.cancel();
                        setState(() {
                          _selectedLocation = 'All Locations';
                          _selectedCategory = null;
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Clear filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                if (snapshot.hasError)
                  _buildHomeLoadFailure()
                else if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Loading jobs…',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (jobs.isEmpty)
                  _buildHomeEmptyState(hasActiveFilters: hasActiveFilters)
                else
                  ...jobs.take(3).map(_buildReferenceJobCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPreferencesPrompt() {
    return Material(
      color: AppTheme.primaryLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedTabIndex = 3),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your preferred roles',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Help us show jobs that fit your goals.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeLoadFailure() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.textSecondary),
          const SizedBox(height: 8),
          const Text(
            'We couldn’t load jobs right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _refreshJobs,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeEmptyState({required bool hasActiveFilters}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.work_outline_rounded,
            size: 34,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            hasActiveFilters ? 'No matching jobs yet' : 'No jobs posted yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasActiveFilters
                ? 'Try a different search or clear your filters.'
                : 'New opportunities will appear here when they are available.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _searchDebounce?.cancel();
                setState(() {
                  _selectedLocation = 'All Locations';
                  _selectedCategory = null;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _getCategoryIconForTitle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tech') ||
        lower.contains('software') ||
        lower.contains('it')) {
      return Icons.code_rounded;
    }
    if (lower.contains('manufactur') ||
        lower.contains('production') ||
        lower.contains('auto')) {
      return Icons.precision_manufacturing_outlined;
    }
    if (lower.contains('market') ||
        lower.contains('sales') ||
        lower.contains('retail')) {
      return Icons.campaign_outlined;
    }
    if (lower.contains('finance') ||
        lower.contains('bank') ||
        lower.contains('account')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('health') ||
        lower.contains('medic') ||
        lower.contains('pharma')) {
      return Icons.favorite_outline;
    }
    if (lower.contains('educat') ||
        lower.contains('teach') ||
        lower.contains('school')) {
      return Icons.school_outlined;
    }
    if (lower.contains('support') ||
        lower.contains('bpo') ||
        lower.contains('customer')) {
      return Icons.headset_mic_outlined;
    }
    if (lower.contains('logistic') ||
        lower.contains('supply') ||
        lower.contains('warehouse')) {
      return Icons.local_shipping_outlined;
    }
    if (lower.contains('hospital') ||
        lower.contains('hotel') ||
        lower.contains('tour')) {
      return Icons.restaurant_outlined;
    }
    if (lower.contains('construct') || lower.contains('real estate')) {
      return Icons.home_work_outlined;
    }
    return Icons.work_outline_rounded;
  }

  Widget _buildCategoryGrid() {
    final defaults = [
      {
        'name': 'IT & Software',
        'icon': Icons.code_rounded,
        'color': const Color(0xFFEFF8FF),
        'iconColor': AppTheme.primary,
      },
      {
        'name': 'Manufacturing',
        'icon': Icons.precision_manufacturing_outlined,
        'color': const Color(0xFFFFF7ED),
        'iconColor': const Color(0xFFEA580C),
      },
      {
        'name': 'Sales & Marketing',
        'icon': Icons.campaign_outlined,
        'color': const Color(0xFFF0FDF4),
        'iconColor': const Color(0xFF16A34A),
      },
      {
        'name': 'Finance & Banking',
        'icon': Icons.account_balance_rounded,
        'color': const Color(0xFFFAF5FF),
        'iconColor': const Color(0xFF9333EA),
      },
      {
        'name': 'Healthcare & Medical',
        'icon': Icons.favorite_outline,
        'color': const Color(0xFFFEF2F2),
        'iconColor': const Color(0xFFDC2626),
      },
      {
        'name': 'Education & EdTech',
        'icon': Icons.school_outlined,
        'color': const Color(0xFFFFFBEB),
        'iconColor': const Color(0xFFD97706),
      },
    ];
    final categories = _managedCategories.isEmpty
        ? defaults
        : _managedCategories.map((item) {
            final title = (item['title'] as String?) ?? 'Category';
            final index = (_managedCategories.indexOf(item)) % defaults.length;
            return <String, dynamic>{
              'name': title,
              'icon': _getCategoryIconForTitle(title),
              'color': defaults[index]['color'],
              'iconColor': defaults[index]['iconColor'],
            };
          }).toList();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = categories[idx];
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;
          final color = cat['color'] as Color;
          final iconColor = cat['iconColor'] as Color;
          final isSelected = _selectedCategory == name;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '$name category',
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_selectedCategory == name) {
                    _selectedCategory = null;
                  } else {
                    _selectedCategory = name;
                  }
                });
              },
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 148,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryLight : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReferenceJobCard(JobModel job) {
    final isSaved = _savedJobIds.contains(job.id);
    final isApplied = _appliedJobIds.contains(job.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: job.isFeatured ? const Color(0xFFFCD34D) : AppTheme.border,
          width: job.isFeatured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: job.isFeatured
                ? const Color(0xFFD97706).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showJobDetails(job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (job.isFeatured || job.isStatewide) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (job.isFeatured)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFD97706),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'FEATURED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (job.isStatewide)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFDDD6FE),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.public_rounded,
                                  size: 12,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'ALL TAMIL NADU',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                // Top row: Avatar, Title, Bookmark
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompanyAvatar(job.companyName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  job.companyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (job.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isSaved ? 'Remove bookmark' : 'Save job',
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        size: 22,
                      ),
                      onPressed: () => _toggleSaveJob(job.id),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Location & Work Mode
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${job.locationCity} • ${job.workMode}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatPostedAge(job.postedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: Salary Pill & Apply Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          job.salaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isApplied) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Applied ✓',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        ElevatedButton(
                          onPressed: () => _showJobDetails(job),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 13),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPostedAge(DateTime postedAt) {
    final age = DateTime.now().difference(postedAt);
    if (age.isNegative || age.inMinutes < 60) return 'Posted recently';
    if (age.inHours < 24) return 'Posted ${age.inHours}h ago';
    if (age.inDays == 1) return 'Posted yesterday';
    return 'Posted ${age.inDays}d ago';
  }

  Widget _buildCompanyAvatar(String companyName, {double size = 40}) {
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
        borderRadius: BorderRadius.circular(10),
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

  // --- CANDIDATE SEARCH SCREEN ---
  Widget _buildCandidateSearchScreen() {
    return StreamBuilder<List<JobModel>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        final jobs = _filterCandidateJobs(snapshot.data ?? []);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Explore jobs',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse live job opportunities.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            // Search & Location Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search jobs, companies, locations...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.primary,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, color: AppTheme.primary),
                    onPressed: _showFilterModal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(children: [
                  const Text('Live jobs are unavailable right now. Check your connection and try again.',
                    style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _refreshJobs, child: const Text('Retry')),
                ]),
              )
            else if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (jobs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No matching live jobs found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Try adjusting your search terms or filters.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else if (jobs.isNotEmpty) ...[
              Text(
                'Live jobs · ${jobs.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ...jobs.map((job) => _buildReferenceJobCard(job)),
            ],
          ],
        );
      },
    );
  }

  // --- CANDIDATE SAVED SCREEN ---
  Widget _buildCandidateSavedScreen() {
    return StreamBuilder<List<JobModel>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        final allJobs = snapshot.data ?? [];
        final savedJobs = allJobs.where((job) => _savedJobIds.contains(job.id)).toList();

        if (snapshot.hasError || _savedJobsLoadFailed) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Could not load saved jobs. Check your connection and try again.'),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () {
                _refreshJobs();
                if (_savedJobsLoadFailed) _subscribeSavedJobs();
              }, child: const Text('Retry')),
            ]),
          ));
        }
        if ((snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) ||
            !_savedJobsReady) {
          return const Center(child: CircularProgressIndicator());
        }

        if (savedJobs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bookmark_border_rounded,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _savedJobIds.isEmpty ? 'No Saved Jobs Yet' : 'No saved jobs available',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _savedJobIds.isEmpty
                        ? 'Bookmark opportunities while browsing to review them later.'
                        : 'The jobs you bookmarked have closed or expired.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => setState(() => _selectedTabIndex = 0),
                    child: const Text('Browse Job Feed'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Jobs',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${savedJobs.length} Bookmarked',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...savedJobs.map((job) => _buildReferenceJobCard(job)),
          ],
        );
      },
    );
  }

  // --- CANDIDATE PROFILE SCREEN ---
  Widget _buildCandidateProfileScreen() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _firestoreService.streamCandidateProfile(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppTheme.textSecondary,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We couldn’t load your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;
        final fullName = _profileString(profile, 'fullName').isNotEmpty
            ? _profileString(profile, 'fullName')
            : AppAuthBridge.currentUser?.displayName ?? 'Candidate';
        final phone = _profileString(profile, 'phone');
        final qualification = _profileString(profile, 'qualification');
        final educationLevel = _profileString(profile, 'educationLevel');
        final preferredRoles = _profileStringList(
          profile?['preferredJobTitles'],
        );
        final email =
            AppAuthBridge.currentUser?.email ??
            _profileString(profile, 'email');
        final birthMonth = _profileString(profile, 'birthMonth');
        final birthYear = _profileString(profile, 'birthYear');
        final birthDisplay = [
          birthMonth,
          if (birthYear.isNotEmpty && birthYear != '0') birthYear,
        ].where((part) => part.isNotEmpty).join(' ');
        final hasExperience = profile?['hasExperience'] == true;
        final experienceRecorded = profile?['hasExperience'] is bool;
        final profilePhotoUrl = _profileString(profile, 'profilePhotoUrl');
        final initials = fullName
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0])
            .join()
            .toUpperCase();
        final district = _profileString(profile, 'district');
        final candidateSubtitle = preferredRoles.isNotEmpty
            ? preferredRoles.first + (district.isNotEmpty ? ' • $district' : '')
            : (district.isNotEmpty ? district : 'Job Seeker');

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Row: Avatar | Vertical Divider | Candidate Details | Squircle Edit Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Candidate Photo
                      GestureDetector(
                        onTap: _isUploadingPhoto
                            ? null
                            : () => _showPhotoActions(profile ?? {}),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFDBEAFE),
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: profilePhotoUrl.isNotEmpty
                              ? Image.network(
                                  profilePhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      _buildProfileInitials(initials),
                                )
                              : _buildProfileInitials(initials),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Subtle vertical divider line
                      Container(
                        width: 1,
                        height: 52,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 14),
                      // Full Name, Subtitle, and Status Badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              candidateSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCandidateStatusBadge(
                              experienceRecorded: experienceRecorded,
                              hasExperience: hasExperience,
                              experienceYears: _profileString(
                                profile,
                                'experienceYears',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Squircle edit/photo icon button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isUploadingPhoto
                              ? null
                              : () => _showPhotoActions(profile ?? {}),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: _isUploadingPhoto
                                ? const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.edit_outlined,
                                    color: AppTheme.primary,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 16),
                  // Bottom Dual Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openCandidateApplications,
                          icon: const Icon(
                            Icons.work_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Applied Jobs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(
                              color: AppTheme.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openCandidateProfileEditor(profile),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Profile details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildProfileFactsSection(
              title: 'Personal information',
              icon: Icons.person_outline_rounded,
              fields: [
                ('Email', _orNotProvided(email)),
                ('Phone number', _orNotProvided(phone)),
                ('Gender', _profileValue(profile, 'gender')),
                ('Marital status', _profileValue(profile, 'maritalStatus')),
                ('Birth month / year', _orNotProvided(birthDisplay)),
                ('Age', _profileValue(profile, 'age')),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileFactsSection(
              title: 'Location',
              icon: Icons.location_on_outlined,
              fields: [
                ('District', _profileValue(profile, 'district')),
                ('State', _profileValue(profile, 'state')),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileFactsSection(
              title: 'Education',
              icon: Icons.school_outlined,
              fields: [
                ('Education level', _orNotProvided(educationLevel)),
                ('Qualification', _orNotProvided(qualification)),
                (
                  'College or school',
                  _profileValue(profile, 'collegeOrSchool'),
                ),
                ('Graduation year', _profileValue(profile, 'graduationYear')),
              ],
            ),
            const SizedBox(height: 16),
            _buildProfileFactsSection(
              title: 'Career preferences',
              icon: Icons.work_outline_rounded,
              fields: [
                (
                  'Preferred job titles',
                  _orNotProvided(preferredRoles.join(', ')),
                ),
                (
                  'Work experience',
                  experienceRecorded
                      ? (hasExperience ? 'Experienced' : 'Fresher')
                      : 'Not provided',
                ),
                if (hasExperience) ...[
                  (
                    'Experience length',
                    _orNotProvided(
                      [
                            _profileString(profile, 'experienceYears'),
                            _profileString(profile, 'experienceMonths'),
                          ]
                          .where((part) => part.isNotEmpty && part != '0')
                          .join(' '),
                    ),
                  ),
                  ('Last company', _profileValue(profile, 'lastCompany')),
                  ('Last job title', _profileValue(profile, 'lastJobTitle')),
                  ('Salary', _profileValue(profile, 'salary')),
                  ('Notice period', _profileValue(profile, 'noticePeriod')),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Your profile information is handled according to our ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  InkWell(
                    onTap: () => PrivacyPolicyScreen.open(context),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _confirmCandidateSignOut,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign out'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        );
      },
    );
  }

  String _profileString(Map<String, dynamic>? profile, String key) {
    final value = profile?[key];
    return value == null ? '' : value.toString().trim();
  }

  List<String> _profileStringList(dynamic value) {
    if (value is! Iterable) return [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  Widget _buildProfileInitials(String initials) {
    return Container(
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? 'C' : initials,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildCandidateStatusBadge({
    required bool experienceRecorded,
    required bool hasExperience,
    required String experienceYears,
  }) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String label;

    if (!experienceRecorded) {
      bgColor = const Color(0xFFFEF3C7);
      textColor = const Color(0xFFB45309);
      icon = Icons.access_time_rounded;
      label = 'Profile in progress';
    } else if (hasExperience) {
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF1D4ED8);
      icon = Icons.work_history_rounded;
      label = experienceYears.isNotEmpty && experienceYears != '0'
          ? '$experienceYears yrs exp'
          : 'Experienced';
    } else {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF15803D);
      icon = Icons.school_rounded;
      label = 'Fresher';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _orNotProvided(String value) =>
      value.trim().isEmpty || value.trim() == '0'
      ? 'Not provided'
      : value.trim();

  String _profileValue(Map<String, dynamic>? profile, String key) =>
      _orNotProvided(_profileString(profile, key));

  Widget _buildProfileSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileFactsSection({
    required String title,
    required IconData icon,
    required List<(String, String)> fields,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileSectionTitle(title, icon),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fields[index].$1,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fields[index].$2,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < fields.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppTheme.border.withValues(alpha: 0.55),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _openCandidateProfileEditor(Map<String, dynamic>? profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => CandidateOnboardingWizardScreen(
          onFinish: () => Navigator.pop(routeContext),
          onBackToLogin: () => Navigator.pop(routeContext),
          initialProfile: profile,
        ),
      ),
    );
  }

  void _openCandidateApplications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CandidateApplicationsScreen(
          candidateUid: _currentUid,
          firestoreService: _firestoreService,
        ),
      ),
    );
  }

  Future<void> _showPhotoActions(Map<String, dynamic> profile) async {
    final hasCustomPhoto = _profileString(
      profile,
      'profilePhotoUrl',
    ).isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.add_a_photo_outlined,
                color: AppTheme.primary,
              ),
              title: Text(
                hasCustomPhoto ? 'Change profile photo' : 'Add profile photo',
              ),
              subtitle: const Text('JPG, PNG, or WebP · up to 3 MB'),
              onTap: () => Navigator.pop(sheetContext, 'upload'),
            ),
            if (hasCustomPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                ),
                title: const Text('Remove profile photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'upload') {
      await _pickAndUploadPhoto();
    } else if (action == 'remove') {
      await _removeProfilePhoto();
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
    } catch (_) {
      _showProfileMessage('Could not open the photo picker. Try again.');
      return;
    }
    if (file == null || !mounted) return;
    Uint8List bytes;
    try {
      final size = await file.length();
      if (size == null || size == 0 || size > 3 * 1024 * 1024) {
        _showProfileMessage('Choose a photo under 3 MB.');
        return;
      }
      bytes = await file.readAsBytes();
    } catch (_) {
      _showProfileMessage('Could not read that photo. Try again.');
      return;
    }
    if (!_looksLikeProfilePhoto(bytes)) {
      _showProfileMessage('Choose a valid JPG, PNG, or WebP photo.');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Use this profile photo?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                bytes,
                width: 130,
                height: 130,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 80),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Your photo may be shown with your candidate profile.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Upload photo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isUploadingPhoto = true);
    try {
      await _candidatePhotoService.upload(uid: _currentUid, bytes: bytes);
      _showProfileMessage('Profile photo updated.');
    } catch (error) {
      _showProfileMessage(
        error is StateError ? error.message : 'Could not upload your photo. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  bool _looksLikeProfilePhoto(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff;
    final png =
        bytes[0] == 0x89 && String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG';
    final webp =
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    return jpeg || png || webp;
  }

  Future<void> _removeProfilePhoto() async {
    setState(() => _isUploadingPhoto = true);
    try {
      await _candidatePhotoService.delete(_currentUid);
      _showProfileMessage('Profile photo removed.');
    } catch (error) {
      _showProfileMessage(
        error is StateError
            ? error.message
            : 'Could not remove your photo. Try again.',
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showProfileMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCandidateSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in to access your profile and saved jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut == true && mounted) widget.onSignOutRequested();
  }

  // --- EMPLOYER VIEWS ---
  Widget _buildEmployerOverview() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(),
      builder: (context, jobsSnap) {
        final jobCount = jobsSnap.data?.length ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.streamRecruiterApplicants(
            employerUid: _currentUid,
          ),
          builder: (context, appSnap) {
            final appCount = appSnap.data?.length ?? 0;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recruiter ATS Dashboard',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Live Firestore Integration • Real-Time Candidate Applications',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(
                            label: 'Live Jobs',
                            value: '$jobCount',
                            highlight: true,
                          ),
                          _MetricItem(
                            label: 'Total Applicants',
                            value: '$appCount',
                            highlight: true,
                          ),
                          const _MetricItem(
                            label: 'ATS Status',
                            value: 'Active',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick Recruiter Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedTabIndex = 1),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Post Job'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedTabIndex = 2),
                              icon: const Icon(
                                Icons.people_alt_outlined,
                                size: 18,
                              ),
                              label: const Text('Applicants'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateJobPost() async {
    final title = _postTitleController.text.trim();
    final company = _postCompanyController.text.trim();
    final salary = _postSalaryController.text.trim();
    final vacancies = int.tryParse(_postVacanciesController.text.trim()) ?? 1;
    final desc = _postDescController.text.trim();

    if (title.isEmpty || company.isEmpty || salary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(
            'Please fill in Job Title, Company Name, and Salary Range.',
          ),
        ),
      );
      return;
    }

    setState(() => _isPostingJob = true);

    try {
      final newJob = JobModel(
        id: '',
        title: title,
        companyName: company,
        locationCity: _postLocation,
        salaryText: salary.startsWith('₹') ? salary : '₹$salary',
        category: _postCategory,
        workMode: _postWorkMode,
        vacanciesCount: vacancies,
        description: desc.isNotEmpty
            ? desc
            : 'We are seeking a talented $title to join our growing team at $company.',
        employerUid: _currentUid,
        isVerified: true,
        postedAt: DateTime.now(),
      );

      await EmployerApiService().publishJob(newJob.toMap());

      if (!mounted) return;
      setState(() {
        _isPostingJob = false;
        _postTitleController.clear();
        _postCompanyController.clear();
        _postSalaryController.clear();
        _postVacanciesController.clear();
        _postDescController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          content: Text('Job posted successfully to Cloud Firestore!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingJob = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Failed to publish job: $e'),
          ),
        );
      }
    }
  }

  Widget _buildEmployerPostJob() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Job Vacancy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Publish vacancies live to all registered candidates in Cloud Firestore.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Divider(height: 24),

              // Job Title
              const Text(
                'Job Title*',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _postTitleController,
                decoration: InputDecoration(
                  hintText: 'e.g. Senior Flutter Developer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Company Name
              const Text(
                'Company Name*',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _postCompanyController,
                decoration: InputDecoration(
                  hintText: 'e.g. Zoho Corporation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category & Work Mode Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category*',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'IT & Software',
                              child: Text(
                                'IT & Software',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Marketing',
                              child: Text(
                                'Marketing',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Finance',
                              child: Text(
                                'Finance',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Design',
                              child: Text(
                                'Design',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Healthcare',
                              child: Text(
                                'Healthcare',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Education',
                              child: Text(
                                'Education',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _postCategory = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Work Mode*',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postWorkMode,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Hybrid',
                              child: Text(
                                'Hybrid',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Remote',
                              child: Text(
                                'Remote',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'On-Site',
                              child: Text(
                                'On-Site',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _postWorkMode = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location & Salary Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location City*',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _postLocation,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Chennai',
                              child: Text(
                                'Chennai',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Coimbatore',
                              child: Text(
                                'Coimbatore',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Bengaluru',
                              child: Text(
                                'Bengaluru',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Erode',
                              child: Text(
                                'Erode',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Salem',
                              child: Text(
                                'Salem',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Madurai',
                              child: Text(
                                'Madurai',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _postLocation = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Salary Text*',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _postSalaryController,
                          decoration: InputDecoration(
                            hintText: 'e.g. ₹8 - 14 LPA',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Vacancies Count
              const Text(
                'Vacancies Available',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _postVacanciesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 2',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Job Description',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _postDescController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Key responsibilities, stack requirements, and candidate qualifications...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              BouncyButton(
                onPressed: _isPostingJob ? null : _handleCreateJobPost,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPostingJob
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : const Text(
                          'Publish Job to Firestore ➔',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployerApplicants() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.streamRecruiterApplicants(
        employerUid: _currentUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final applicants = snapshot.data ?? [];

        if (applicants.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.inbox_rounded,
                    size: 60,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'No Applicants Yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'When candidates apply to live jobs, their profiles will appear here instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applicants.length,
          itemBuilder: (context, idx) {
            final app = applicants[idx];
            final name = app['candidateName']?.toString() ?? 'Applicant';
            final candidateUid = app['candidateUid']?.toString() ?? '';
            final jobTitle = app['jobTitle'] ?? 'Job';
            final email = app['candidateEmail'] ?? '';
            final phone = app['candidatePhone'] ?? '';
            final education = app['education'] ?? '';
            final status = app['status'] ?? 'Applied';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildApplicantAvatar(candidateUid, name),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applied for: $jobTitle',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (phone.isNotEmpty || email.isNotEmpty)
                    Text(
                      'Contact: ${phone.isNotEmpty ? phone : ''} ${email.isNotEmpty ? '• $email' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  if (education.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Education: $education',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApplicantAvatar(String candidateUid, String name) {
    final initials = name.trim().isEmpty ? 'C' : name.trim()[0].toUpperCase();
    Widget fallback() => Text(
      initials,
      style: const TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
    if (candidateUid.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primaryLight,
        child: fallback(),
      );
    }
    return StreamBuilder<String?>(
      stream: _firestoreService.streamCandidatePublicPhoto(candidateUid),
      builder: (context, snapshot) {
        final photoUrl = snapshot.data;
        return CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primaryLight,
          child: photoUrl == null || photoUrl.isEmpty
              ? fallback()
              : ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback(),
                  ),
                ),
        );
      },
    );
  }

  // --- ADMIN VIEWS ---
  Widget _buildAdminPanel() {
    return StreamBuilder<List<JobModel>>(
      stream: _firestoreService.streamJobs(),
      builder: (context, jobSnap) {
        final totalJobs = jobSnap.data?.length ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.streamRecruiterApplicants(
            employerUid: _currentUid,
          ),
          builder: (context, appSnap) {
            final totalApps = appSnap.data?.length ?? 0;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Platform Governance & Master Analytics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricItem(
                            label: 'Live Jobs',
                            value: '$totalJobs',
                            highlight: true,
                          ),
                          _MetricItem(
                            label: 'Applications',
                            value: '$totalApps',
                            highlight: true,
                          ),
                          const _MetricItem(
                            label: 'System Status',
                            value: 'Live 100%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CandidateApplicationsScreen extends StatefulWidget {
  final String candidateUid;
  final SupabaseService firestoreService;

  const _CandidateApplicationsScreen({
    required this.candidateUid,
    required this.firestoreService,
  });

  @override
  State<_CandidateApplicationsScreen> createState() =>
      _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState
    extends State<_CandidateApplicationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applied jobs')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.firestoreService.streamCandidateApplications(
          widget.candidateUid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load your applications.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final applications = snapshot.data ?? [];
          if (applications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.work_history_outlined,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No applications yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Jobs you apply to will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final application = applications[index];
              final title = application['jobTitle']?.toString() ?? 'Job';
              final company =
                  application['companyName']?.toString() ?? 'Company';
              final location = application['locationCity']?.toString() ?? '';
              final status = application['status']?.toString() ?? 'Applied';
              final appliedAt =
                  application['appliedAt'] ?? application['created_at'];
              final appliedDate = appliedAt is DateTime
                  ? appliedAt
                  : appliedAt is String
                  ? DateTime.tryParse(appliedAt)
                  : null;

              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ApplicationStatusLabel(status: status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        company,
                        location,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (appliedDate != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Applied ${appliedDate.day}/${appliedDate.month}/${appliedDate.year}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApplicationStatusLabel extends StatelessWidget {
  final String status;

  const _ApplicationStatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized.contains('reject')
        ? AppTheme.error
        : normalized.contains('short') || normalized.contains('interview')
        ? AppTheme.success
        : AppTheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _MetricItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: highlight ? AppTheme.primary : AppTheme.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
