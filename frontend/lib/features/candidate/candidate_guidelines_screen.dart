import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';

class CandidateGuidelinesScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  final VoidCallback onBack;

  const CandidateGuidelinesScreen({
    super.key,
    required this.onAccepted,
    required this.onBack,
  });

  @override
  State<CandidateGuidelinesScreen> createState() =>
      _CandidateGuidelinesScreenState();
}

class _CandidateGuidelinesScreenState extends State<CandidateGuidelinesScreen> {
  bool _hasAgreed = false;

  void _handleAccept() {
    if (!_hasAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.primaryDark,
          content: Text(
            'Please agree to the Candidate Safety Guidelines to proceed.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        widget.onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: widget.onBack,
          ),
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
                    'CAREER',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '360',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: true,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Blue Banner
                    _buildHeroHeader(isDesktop),

                    const SizedBox(height: 16),

                    // Central Guidelines Card
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildGuidelineRow(
                              icon: Icons.verified_user_outlined,
                              title: 'Verified Employer Network',
                              description:
                                  'All employers are verified through business and organization checks before posting jobs.',
                            ),
                            const Divider(
                              height: 32,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            _buildGuidelineRow(
                              icon: Icons.work_outline_rounded,
                              title: 'Authentic Job Postings',
                              description:
                                  'Job listings include clear titles, work locations, eligibility requirements, and transparent compensation details.',
                            ),
                            const Divider(
                              height: 32,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            _buildGuidelineRow(
                              icon: Icons.lock_outline_rounded,
                              title: 'Data & Privacy Protection',
                              description:
                                  'Your personal details, resume, and application history are kept confidential and shared only with the recruiters you apply to.',
                            ),
                            const Divider(
                              height: 32,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            _buildGuidelineRow(
                              icon: Icons.block_flipped,
                              title: 'Zero Tolerance for Fraud',
                              descriptionRich: TextSpan(
                                text:
                                    'Never transfer funds via UPI, bank transfer, or cash. Report any suspicious activity immediately to ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  height: 1.45,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'support@career360.com.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Support Info Banner
                            _buildSupportBanner(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Agreement Checkbox + CTA Action Section
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 16,
                      ),
                      child: Column(
                        children: [
                          _buildAgreementCheckbox(),
                          const SizedBox(height: 14),
                          _buildActionButton(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Hero Blue Banner ---
  Widget _buildHeroHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A2351),
            Color(0xFF0C3D8F),
            Color(0xFF155EEF),
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 20,
        vertical: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Candidate Safety &\nCommunity Guidelines',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'We ensure a safe, transparent, and trustworthy job ecosystem for every candidate on Career360.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE0E7FF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // High-Trust Vector Shield Badge
          _buildTrustShieldBadge(),
        ],
      ),
    );
  }

  // --- Trust Shield Badge ---
  Widget _buildTrustShieldBadge() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF38BDF8),
              Color(0xFF155EEF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.verified_user_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  // --- Guideline Row Item ---
  Widget _buildGuidelineRow({
    required IconData icon,
    required String title,
    String? description,
    InlineSpan? descriptionRich,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blue Tint Icon Box
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFDBEAFE),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),

        // Text Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 5),
              if (descriptionRich != null)
                Text.rich(descriptionRich)
              else
                Text(
                  description ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Support Info Banner ---
  Widget _buildSupportBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFBAE6FD),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              spacing: 6,
              runSpacing: 4,
              children: const [
                Text(
                  'Have questions or concerns?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'support@career360.com',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Agreement Checkbox ---
  Widget _buildAgreementCheckbox() {
    return InkWell(
      onTap: () {
        setState(() {
          _hasAgreed = !_hasAgreed;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _hasAgreed,
                activeColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                side: const BorderSide(
                  color: Color(0xFF94A3B8),
                  width: 1.8,
                ),
                onChanged: (val) {
                  setState(() {
                    _hasAgreed = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'I understand and agree to the ',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                  children: const [
                    TextSpan(
                      text: 'Candidate Safety Guidelines.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Action Button ---
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _hasAgreed
              ? const LinearGradient(
                  colors: [
                    Color(0xFF155EEF),
                    Color(0xFF0F4AC7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: _hasAgreed ? null : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hasAgreed
              ? [
                  BoxShadow(
                    color: const Color(0xFF155EEF).withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: _handleAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: const Color(0xFF94A3B8),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Accept & Continue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _hasAgreed ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: _hasAgreed ? Colors.white : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
