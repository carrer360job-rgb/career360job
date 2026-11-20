import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/bouncy_button.dart';
import '../../main.dart';

class RoleSelectionScreen extends StatelessWidget {
  final ValueChanged<AppUserRole> onSelectRole;

  const RoleSelectionScreen({super.key, required this.onSelectRole});

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOrTablet = !ResponsiveLayout.isMobile(context);
    final bool isSmall = ResponsiveLayout.isSmallMobile(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Ambient organic mint wave background graphics
          Positioned.fill(
            child: CustomPaint(
              painter: const _RoleBackgroundPainter(),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 16 : (isDesktopOrTablet ? 40 : 20),
                vertical: isDesktopOrTablet ? 32 : 14,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktopOrTablet ? 980 : 460,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      // Top Brand Squircle Emblem
                      Container(
                        width: isDesktopOrTablet ? 76 : 70,
                        height: isDesktopOrTablet ? 76 : 70,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0E000000),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/career360_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Brand Typography: Career360
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Career',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.6,
                            ),
                          ),
                          Text(
                            '360',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Subtitle with green dashes: — JOB PORTAL —
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'JOB PORTAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 26,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Headline: Choose Your Role (Shared Baseline with Positioned Arc)
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Choose Your ',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Role',
                                  style: TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: -5,
                            child: CustomPaint(
                              size: const Size(60, 7),
                              painter: const _ArcUnderlinePainter(
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select how you would like to use Career360',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 26),

                      // Role Cards (Increased gap to 26px between cards)
                      if (isDesktopOrTablet)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildRoleCard(
                                  context: context,
                                  icon: Icons.person_search_rounded,
                                  title: 'Job Seeker',
                                  description:
                                      'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                                  illustration: _buildJobSeekerIllustration(),
                                  buttonText: 'Continue as Job Seeker',
                                  buttonColor: AppTheme.primary,
                                  onTap: () => onSelectRole(AppUserRole.candidate),
                                ),
                              ),
                              const SizedBox(width: 26),
                              Expanded(
                                child: _buildRoleCard(
                                  context: context,
                                  icon: Icons.business_center_rounded,
                                  title: 'Employer / Recruiter',
                                  description:
                                      'Post job vacancies, review qualified applicants, and manage your hiring pipeline.',
                                  illustration: _buildEmployerIllustration(),
                                  buttonText: 'Continue as Employer',
                                  buttonColor: const Color(0xFF064E3B),
                                  onTap: () => onSelectRole(AppUserRole.employer),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _buildRoleCard(
                              context: context,
                              icon: Icons.person_search_rounded,
                              title: 'Job Seeker',
                              description:
                                  'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                              illustration: _buildJobSeekerIllustration(),
                              buttonText: 'Continue as Job Seeker',
                              buttonColor: AppTheme.primary,
                              onTap: () => onSelectRole(AppUserRole.candidate),
                            ),
                            const SizedBox(height: 26),
                            _buildRoleCard(
                              context: context,
                              icon: Icons.business_center_rounded,
                              title: 'Employer / Recruiter',
                              description:
                                  'Post job vacancies, review qualified applicants, and manage your hiring pipeline.',
                              illustration: _buildEmployerIllustration(),
                              buttonText: 'Continue as Employer',
                              buttonColor: const Color(0xFF064E3B),
                              onTap: () => onSelectRole(AppUserRole.employer),
                            ),
                          ],
                        ),

                      // Footer positioned naturally 32dp below Employer card (no Spacer)
                      const SizedBox(height: 32),

                      // Footer URL with Globe Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.language_rounded,
                            size: 15,
                            color: Color(0xFF475569),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'www.career360.com',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildRoleCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Widget illustration,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 22,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left squircle icon (scaled up)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 28,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Middle title and description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right illustration (scaled up)
              illustration,
            ],
          ),
          const SizedBox(height: 18),

          // Full width CTA button (52px height)
          BouncyButton(
            onPressed: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSeekerIllustration() {
    return SizedBox(
      width: 82,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Sparkle rays top right
          Positioned(
            top: 0,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.4,
                  child: Container(
                    width: 2.2,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const SizedBox(width: 3.5),
                Container(
                  width: 2.2,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 3.5),
                Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 2.2,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Resume Document Card (larger)
          Positioned(
            left: 2,
            top: 12,
            child: Container(
              width: 56,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Resume Lines
                  Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF86EFAC),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF86EFAC),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Magnifying Glass (larger)
          Positioned(
            right: 0,
            bottom: 2,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF16A34A),
                        width: 3.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Transform.rotate(
                      angle: -0.75,
                      child: Container(
                        width: 4.5,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerIllustration() {
    return SizedBox(
      width: 82,
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Sparkle rays top right
          Positioned(
            top: 2,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.4,
                  child: Container(
                    width: 2.2,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const SizedBox(width: 3.5),
                Container(
                  width: 2.2,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 3.5),
                Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 2.2,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Buildings Row (larger)
          Positioned(
            bottom: 4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Shorter building (left)
                Container(
                  width: 26,
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(),
                          _windowBox(),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(),
                          _windowBox(),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(),
                          _windowBox(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 3.5),
                // Tall building (right)
                Container(
                  width: 38,
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF047857),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(6),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(isTall: true),
                          _windowBox(isTall: true),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(isTall: true),
                          _windowBox(isTall: true),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(isTall: true),
                          _windowBox(isTall: true),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _windowBox(isTall: true),
                          _windowBox(isTall: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _windowBox({bool isTall = false}) {
    return Container(
      width: isTall ? 6 : 5,
      height: isTall ? 7 : 6,
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

class _ArcUnderlinePainter extends CustomPainter {
  final Color color;
  const _ArcUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.1);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 1.15,
      size.width,
      size.height * 0.1,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoleBackgroundPainter extends CustomPainter {
  const _RoleBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = const Color(0xFFE8F7EE).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Top-left organic curve
    final topLeft = Path();
    topLeft.moveTo(0, 0);
    topLeft.lineTo(size.width * 0.55, 0);
    topLeft.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.12,
      0,
      size.height * 0.18,
    );
    topLeft.close();
    canvas.drawPath(topLeft, wavePaint);

    // Top-right organic curve
    final topRight = Path();
    topRight.moveTo(size.width, 0);
    topRight.lineTo(size.width * 0.45, 0);
    topRight.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.14,
      size.width,
      size.height * 0.24,
    );
    topRight.close();
    canvas.drawPath(topRight, wavePaint);

    // Bottom organic wave
    final bottomWave = Path();
    bottomWave.moveTo(0, size.height);
    bottomWave.lineTo(0, size.height - 70);
    bottomWave.quadraticBezierTo(
      size.width * 0.25,
      size.height - 110,
      size.width * 0.6,
      size.height - 65,
    );
    bottomWave.quadraticBezierTo(
      size.width * 0.85,
      size.height - 30,
      size.width,
      size.height - 80,
    );
    bottomWave.lineTo(size.width, size.height);
    bottomWave.close();
    canvas.drawPath(bottomWave, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
