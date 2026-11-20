import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/services/supabase_auth_service.dart';
import '../../core/widgets/bouncy_button.dart';

/// The last step of the shared recovery flow, styled like each role's auth page.
class PasswordRecoveryCompletionScreen extends StatefulWidget {
  final PasswordRecoveryRole role;

  const PasswordRecoveryCompletionScreen({super.key, required this.role});

  @override
  State<PasswordRecoveryCompletionScreen> createState() =>
      _PasswordRecoveryCompletionScreenState();
}

class _PasswordRecoveryCompletionScreenState
    extends State<PasswordRecoveryCompletionScreen> {
  static const _deepForest = Color(0xFF064E3B);
  static const _deepPine = Color(0xFF065F46);
  static const _emerald = Color(0xFF16A34A);
  static const _navy = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFD0D5DD);

  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _visible = false;
  String? _error;

  String get _roleLabel => switch (widget.role) {
    PasswordRecoveryRole.candidate => 'JOB SEEKER',
    PasswordRecoveryRole.employer => 'EMPLOYER',
  };

  String get _signInLabel => switch (widget.role) {
    PasswordRecoveryRole.candidate => 'Candidate Sign In',
    PasswordRecoveryRole.employer => 'Employer Sign In',
  };

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Passwords do not match. Please try again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseAuthService().updatePasswordAfterRecovery(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed. Sign in with your new password.'),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Could not save your password. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseAuthService().cancelPasswordRecovery();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not sign out. Please try again.';
        });
      }
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputAction action,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 52,
        child: TextFormField(
          controller: controller,
          obscureText: !_visible,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: action,
          onFieldSubmitted: action == TextInputAction.done
              ? (_) => _save()
              : null,
          style: const TextStyle(fontSize: 15, color: _navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: _muted,
              size: 20,
            ),
            suffixIcon: IconButton(
              tooltip: _visible ? 'Hide password' : 'Show password',
              icon: Icon(
                _visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: _muted,
                size: 20,
              ),
              onPressed: () => setState(() => _visible = !_visible),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _emerald, width: 1.8),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _cancel();
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to sign in',
          icon: const Icon(Icons.arrow_back, color: _navy),
          onPressed: _busy ? null : _cancel,
        ),
        centerTitle: true,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/career360_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'CAREER',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _deepForest,
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                '360',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _emerald,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF86EFAC),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _roleLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
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
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 52),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_deepForest, _deepPine, _emerald],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      color: Color(0xFF86EFAC),
                                      size: 14,
                                    ),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Security & Access Recovery',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Set New Password',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Your email is verified. Create a new password to finish recovering your account.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Transform.translate(
                            offset: const Offset(0, -28),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                24,
                              ),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFBBF7D0),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.mark_email_read_outlined,
                                          color: _deepPine,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Email verified',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: _deepForest,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'You can now create a new password.',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color: _muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _passwordField(
                                    controller: _password,
                                    label: 'New Password *',
                                    hint: 'Enter new password (min. 6 characters)',
                                    action: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 14),
                                  _passwordField(
                                    controller: _confirmation,
                                    label: 'Confirm New Password *',
                                    hint: 'Re-enter new password to confirm',
                                    action: TextInputAction.done,
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFB42318),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  BouncyButton(
                                    onPressed: _busy ? null : _save,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [_deepPine, _emerald],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _busy
                                            ? 'Saving password...'
                                            : 'Save New Password',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: _busy ? null : _cancel,
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        size: 16,
                                      ),
                                      label: Text('Back to $_signInLabel'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _deepPine,
                                      ),
                                    ),
                                  ),
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
          ),
        ),
      ),
    ),
  );
}
