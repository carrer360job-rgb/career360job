import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Hiring rules shown before an employer continues to sign in.
class EmployerGuidelinesScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onBack;

  const EmployerGuidelinesScreen({
    super.key,
    required this.onAccepted,
    required this.onBack,
  });

  @override
  State<EmployerGuidelinesScreen> createState() =>
      _EmployerGuidelinesScreenState();
}

class _EmployerGuidelinesScreenState extends State<EmployerGuidelinesScreen> {
  bool _hasAgreed = false;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) widget.onBack();
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/career360_icon.png',
              width: 27,
              height: 27,
            ),
            const SizedBox(width: 6),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'CAREER',
                    style: TextStyle(color: AppTheme.primaryDark),
                  ),
                  TextSpan(
                    text: '360',
                    style: TextStyle(color: AppTheme.primary),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _hero(),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
                      child: Column(
                        children: [
                          _GuidelineRow(
                            icon: Icons.verified_outlined,
                            title: 'Instant company onboarding',
                            description: 'Enter your business details and start managing hiring immediately.',
                          ),
                          _GuidelineRow(
                            icon: Icons.subject_rounded,
                            title: 'Describe the role clearly',
                            description: 'Include accurate pay, work location, and requirements.',
                          ),
                          _GuidelineRow(
                            icon: Icons.shield_outlined,
                            title: 'Respect candidate privacy',
                            description: 'Use resumes and contact details only for recruitment.',
                          ),
                          _GuidelineRow(
                            icon: Icons.block_outlined,
                            title: 'Never charge candidates',
                            description: 'Do not ask for application fees, deposits, or interview charges.',
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 21),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A2351), Color(0xFF0C3D8F), AppTheme.primary],
      ),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Employer hiring\nguidelines',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'What to know before your first job goes live.',
                style: TextStyle(
                  color: Color(0xFFE0E7FF),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: const Icon(
            Icons.business_center_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
      ],
    ),
  );

  Widget _footer() => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            value: _hasAgreed,
            onChanged: (value) => setState(() => _hasAgreed = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'I agree to the employer hiring guidelines.',
              style: TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _hasAgreed ? widget.onAccepted : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Accept & Continue'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuidelineRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool showDivider;

  const _GuidelineRow({
    required this.icon,
    required this.title,
    required this.description,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Icon(icon, color: AppTheme.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (showDivider) ...[
        const SizedBox(height: 19),
        const Padding(
          padding: EdgeInsets.only(left: 34),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
        const SizedBox(height: 19),
      ],
    ],
  );
}
