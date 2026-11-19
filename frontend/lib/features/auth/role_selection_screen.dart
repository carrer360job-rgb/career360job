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
          // Ambient soft mint top background glow
          Positioned(
            top: -100,
            left: -60,
            right: -60,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryLight.withValues(alpha: 0.7),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 16 : (isDesktopOrTablet ? 40 : 22),
                  vertical: isDesktopOrTablet ? 40 : 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktopOrTablet ? 980 : 460,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Brand Emblem Badge
                      Container(
                        width: isDesktopOrTablet ? 74 : 64,
                        height: isDesktopOrTablet ? 74 : 64,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryLightBorder,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.14),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/career360_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Brand Typography: Career360
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Career',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '360',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '—  JOB PORTAL  —',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 2.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Headings
                      Text(
                        'Choose Your Role',
                        style: TextStyle(
                          fontSize: isDesktopOrTablet ? 26 : 24,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select how you would like to use Career360',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Responsive Role Cards (3 Columns on Desktop/Tablet, Stacked on Mobile)
                      if (isDesktopOrTablet)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildCorporateRoleCard(
                                  context: context,
                                  icon: Icons.person_search_rounded,
                                  iconColor: AppTheme.primary,
                                  title: 'Job Seeker',
                                  description:
                                      'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                                  buttonText: 'Continue as Job Seeker',
                                  buttonColor: AppTheme.primary,
                                  onTap: () => onSelectRole(AppUserRole.candidate),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _buildCorporateRoleCard(
                                  context: context,
                                  icon: Icons.business_center_rounded,
                                  iconColor: AppTheme.primaryDark,
                                  title: 'Employer / Recruiter',
                                  description:
                                      'Post job vacancies, review qualified applicants, and manage your hiring pipeline.',
                                  buttonText: 'Continue as Employer',
                                  buttonColor: AppTheme.primaryDark,
                                  onTap: () => onSelectRole(AppUserRole.employer),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: _buildCorporateRoleCard(
                                  context: context,
                                  icon: Icons.school_rounded,
                                  iconColor: AppTheme.primary,
                                  title: 'Institution',
                                  description:
                                      'Manage students, placements and campus recruitment, and connect with top employers.',
                                  buttonText: 'Continue as Institution',
                                  buttonColor: AppTheme.primary,
                                  onTap: () => onSelectRole(AppUserRole.institution),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _buildCorporateRoleCard(
                              context: context,
                              icon: Icons.person_search_rounded,
                              iconColor: AppTheme.primary,
                              title: 'Job Seeker',
                              description:
                                  'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                              buttonText: 'Continue as Job Seeker',
                              buttonColor: AppTheme.primary,
                              onTap: () => onSelectRole(AppUserRole.candidate),
                            ),
                            const SizedBox(height: 16),
                            _buildCorporateRoleCard(
                              context: context,
                              icon: Icons.business_center_rounded,
                              iconColor: AppTheme.primaryDark,
                              title: 'Employer / Recruiter',
                              description:
                                  'Post job vacancies, review qualified applicants, and manage your hiring pipeline.',
                              buttonText: 'Continue as Employer',
                              buttonColor: AppTheme.primaryDark,
                              onTap: () => onSelectRole(AppUserRole.employer),
                            ),
                            const SizedBox(height: 16),
                            _buildCorporateRoleCard(
                              context: context,
                              icon: Icons.school_rounded,
                              iconColor: AppTheme.primary,
                              title: 'Institution',
                              description:
                                  'Manage students, placements and campus recruitment, and connect with top employers.',
                              buttonText: 'Continue as Institution',
                              buttonColor: AppTheme.primary,
                              onTap: () => onSelectRole(AppUserRole.institution),
                            ),
                          ],
                        ),

                      const SizedBox(height: 36),

                      // Footer URL with Globe Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.language_rounded,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'www.career360.com',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
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

  Widget _buildCorporateRoleCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Icon Badge with Soft Mint Background
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryLightBorder,
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, size: 25, color: iconColor),
              ),
              const SizedBox(width: 14),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
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
          const SizedBox(height: 16),

          // Action Button
          BouncyButton(
            onPressed: onTap,
            borderRadius: BorderRadius.circular(12),
            pressOverlayColor: Colors.black.withValues(alpha: 0.15),
            child: Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      buttonText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
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
}
