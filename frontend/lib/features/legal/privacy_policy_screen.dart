import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Navigates to the Privacy Policy as a full separate screen
  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacyPolicyScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryDark,
          ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 20,
              vertical: 16,
            ),
            children: [
              // Document Header
              const Text(
                'Career360 Privacy Policy',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Career360 Technologies Private Limited',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Effective Date: November 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 18),

              // Preamble
              const Text(
                'Please read this Privacy Policy carefully before using the Career360 mobile application or website. This document explains our policies and practices regarding the collection, use, security, and disclosure of your personal information when you access our job portal services.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 22),

              // Section 1
              _buildSectionTitle('1. Information We Collect Through Our App'),
              const SizedBox(height: 8),
              _buildSubTitle('1.1. Personally Identifiable Information'),
              _buildParagraph(
                'Career360 collects personal details that you voluntarily submit when creating your candidate account, updating your profile, or applying for vacancies. This includes your full name, email address, mobile phone number, current city, educational qualifications, employment history, portfolio links, and uploaded resume document (PDF or DOCX).',
              ),
              const SizedBox(height: 10),
              _buildSubTitle('1.2. Non-Personally Identifiable Information'),
              _buildParagraph(
                'When you access the Career360 application, our systems automatically log non-identifiable technical metrics. This includes device hardware model, operating system version, unique device identifiers, network connection type, and crash log analytics to ensure application stability and reliability.',
              ),
              const SizedBox(height: 22),

              // Section 2
              _buildSectionTitle('2. How Career360 Uses Your Information'),
              const SizedBox(height: 8),
              _buildParagraph(
                'We use candidate information strictly for recruitment facilitation and legitimate platform operations:',
              ),
              _buildBullet('Matching your skill sets and career preferences with verified job opportunities across Indian cities.'),
              _buildBullet('Transmitting your resume, contact details, and application data directly to verified employers upon your explicit application.'),
              _buildBullet('Providing real-time notifications regarding application reviews, recruiter shortlists, and interview updates.'),
              _buildBullet('Detecting and preventing unauthorized consultancies, fraudulent job offers, and payment scams.'),
              const SizedBox(height: 22),

              // Section 3
              _buildSectionTitle('3. Data Security & Storage Standards'),
              const SizedBox(height: 8),
              _buildParagraph(
                'We implement strict physical, electronic, and administrative safeguards. All data transmitted between your device and Career360 servers is encrypted using 256-bit SSL (Secure Socket Layer) transport encryption.',
              ),
              _buildParagraph(
                'User credentials, phone OTP sessions, and authentication tokens are salted and securely hashed. Career360 does not store banking credentials, credit/debit card numbers, or financial account details of candidates.',
              ),
              const SizedBox(height: 22),

              // Section 4
              _buildSectionTitle('4. Sharing of Personal Information'),
              const SizedBox(height: 8),
              _buildParagraph(
                'We have a strict zero-sale policy: Career360 does NOT sell, rent, monetize, or trade candidate personal identification information with any third-party marketing brokers or advertising networks.',
              ),
              _buildParagraph(
                'Your profile and resume are shared exclusively with verified hiring organizations that you choose to apply to. We may disclose personal data only when required to do so by applicable Indian law, court order, or governmental authority.',
              ),
              const SizedBox(height: 22),

              // Section 5
              _buildSectionTitle('5. Cookies & Analytics Technologies'),
              const SizedBox(height: 8),
              _buildParagraph(
                'Our mobile application and web portals use session identifiers and crash diagnostics (such as Google Firebase) to maintain your login session, prevent repeated logins, and diagnose performance issues. You may manage device permissions or clear app storage at any time.',
              ),
              const SizedBox(height: 22),

              // Section 6
              _buildSectionTitle('6. Candidate Rights & Account Deletion'),
              const SizedBox(height: 8),
              _buildParagraph(
                'You maintain complete ownership of your personal information:',
              ),
              _buildBullet('You have the right to review, edit, or replace your resume and contact information at any time in your profile.'),
              _buildBullet('You have the right to opt out of promotional communications and email updates.'),
              _buildBullet('You have the right to request permanent deletion of your account and all associated personal data from our systems.'),
              const SizedBox(height: 8),
              _buildParagraph(
                'To request account and data deletion, email privacy@career360.com with your registered mobile number. Your account and records will be permanently removed within 7 business days.',
              ),
              const SizedBox(height: 22),

              // Section 7
              _buildSectionTitle('7. Contact & Grievance Officer'),
              const SizedBox(height: 8),
              _buildParagraph(
                'In accordance with the Indian Information Technology Act and rules made thereunder, the contact details of our Grievance Officer are provided below:',
              ),
              const SizedBox(height: 4),
              _buildContactItem('Company:', 'Career360 Technologies Private Limited'),
              _buildContactItem('Legal Email:', 'privacy@career360.com'),
              _buildContactItem('Help Desk:', 'support@career360.com'),
              _buildContactItem('Registered Office:', 'OMR Tech Corridor, Chennai, Tamil Nadu - 600096, India'),
              const SizedBox(height: 32),

              // Return Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Understood & Return',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryDark,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildSubTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
