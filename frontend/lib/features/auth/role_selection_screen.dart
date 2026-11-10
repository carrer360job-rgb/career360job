import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../main.dart';

class RoleSelectionScreen extends StatelessWidget {
  final ValueChanged<AppUserRole> onSelectRole;

  const RoleSelectionScreen({super.key, required this.onSelectRole});

  @override
  Widget build(BuildContext context) {
    final bool isDesktopOrTablet = !ResponsiveLayout.isMobile(context);
    final bool isSmall = ResponsiveLayout.isSmallMobile(context);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 16 : (isDesktopOrTablet ? 40 : 24),
              vertical: isDesktopOrTablet ? 40 : 20,
            ),
            child: ConstrainedBox(
              // Allow wider container on tablets/laptops for side-by-side cards
              constraints: BoxConstraints(
                maxWidth: isDesktopOrTablet ? 860 : 440,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Brand Emblem Badge
                  Container(
                    width: isDesktopOrTablet ? 80 : 68,
                    height: isDesktopOrTablet ? 80 : 68,
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(isDesktopOrTablet ? 22 : 18),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/career360_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Brand Typography: Career360
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Career',
                        style: TextStyle(
                          fontSize: isDesktopOrTablet ? 30 : 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        '360',
                        style: TextStyle(
                          fontSize: isDesktopOrTablet ? 30 : 26,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'JOB PORTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 3.0,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Headings
                  Text(
                    'Choose Your Role',
                    style: TextStyle(
                      fontSize: isDesktopOrTablet ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select how you would like to use ${AppConstants.appName}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktopOrTablet ? 14 : 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Responsive Role Cards (Side-by-side on Tablets/Laptops, Stacked on Phones)
                  if (isDesktopOrTablet)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildCorporateRoleCard(
                              context: context,
                              icon: Icons.person_search_rounded,
                              iconBgColor: AppTheme.primaryLight,
                              iconColor: AppTheme.primary,
                              title: 'Job Seeker',
                              description:
                                  'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                              buttonText: 'Continue as Job Seeker',
                              buttonColor: AppTheme.primary,
                              onTap: () => onSelectRole(AppUserRole.candidate),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildCorporateRoleCard(
                              context: context,
                              icon: Icons.business_center_rounded,
                              iconBgColor: const Color(0xFFF1F5F9),
                              iconColor: AppTheme.primaryDark,
                              title: 'Employer / Recruiter',
                              description:
                                  'Post job vacancies, review qualified applicants, and manage your hiring pipeline efficiently.',
                              buttonText: 'Continue as Employer',
                              buttonColor: AppTheme.primaryDark,
                              onTap: () => onSelectRole(AppUserRole.employer),
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
                          iconBgColor: AppTheme.primaryLight,
                          iconColor: AppTheme.primary,
                          title: 'Job Seeker',
                          description:
                              'Discover thousands of verified career opportunities, apply with 1-tap, and track interview progress.',
                          buttonText: 'Continue as Job Seeker',
                          buttonColor: AppTheme.primary,
                          onTap: () => onSelectRole(AppUserRole.candidate),
                        ),
                        const SizedBox(height: 18),
                        _buildCorporateRoleCard(
                          context: context,
                          icon: Icons.business_center_rounded,
                          iconBgColor: const Color(0xFFF1F5F9),
                          iconColor: AppTheme.primaryDark,
                          title: 'Employer / Recruiter',
                          description:
                              'Post job vacancies, review qualified applicants, and manage your hiring pipeline efficiently.',
                          buttonText: 'Continue as Employer',
                          buttonColor: AppTheme.primaryDark,
                          onTap: () => onSelectRole(AppUserRole.employer),
                        ),
                      ],
                    ),

                  const SizedBox(height: 32),

                  // Footer URL
                  const Text(
                    'www.career360.com',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorporateRoleCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: buttonColor.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: buttonColor.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      buttonText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
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
