import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import 'widgets/legal_section.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          // Style comes from AppBarTheme.titleTextStyle.
          title: const Text('Privacy Policy'),
          centerTitle: false,
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LastUpdatedBadge('June 2025'),
              SizedBox(height: 20),
              LegalSection(
                title: '1. Introduction',
                body:
                    'Gowai — AI Travel Planner ("Gowai", "we", "us", or "our") is operated by '
                    'Spotroot Technology LLP. This Privacy Policy explains what personal data we collect, '
                    'how we use it, and your rights regarding that data.\n\n'
                    'By using Gowai, you agree to the collection and use of information in accordance '
                    'with this policy.',
              ),
              LegalSection(
                title: '2. Information We Collect',
                body:
                    'We collect the following types of information when you use Gowai:\n\n'
                    '• Email address — used for account creation and sign-in via Supabase authentication.\n\n'
                    '• Name — optional, collected from Google or Apple sign-in if you choose those methods.\n\n'
                    '• Trip data — destinations, preferences, and AI-generated itineraries you create inside the app.\n\n'
                    '• Device information — basic device and OS info collected anonymously to monitor app performance and fix bugs.\n\n'
                    '🔒 We do NOT sell your personal data to any third party, ever.',
              ),
              LegalSection(
                title: '3. How We Use Your Information',
                body: 'We use the data we collect to:\n\n'
                    '• Generate personalised AI trip itineraries tailored to your preferences.\n\n'
                    '• Save and synchronise your trips across devices via your account.\n\n'
                    '• Manage your subscription status (Free or Pro) through RevenueCat.\n\n'
                    '• Monitor and improve app performance and fix technical issues.\n\n'
                    '• Send important service updates (we do not send marketing emails without consent).',
              ),
              LegalSection(
                title: '4. Third-Party Services We Use',
                body:
                    'Gowai integrates with the following third-party services. Each has its own privacy policy:\n\n'
                    '• Anthropic Claude API — powers AI itinerary generation. Your trip prompts are sent to Anthropic\'s servers to generate responses.\n\n'
                    '• Google Maps & Places API — provides mapping, routing, and location data for your itineraries.\n\n'
                    '• Supabase — stores your account profile and trip data securely in the cloud.\n\n'
                    '• RevenueCat — manages subscription billing and entitlements. We never see your payment card details.\n\n'
                    '• Google Sign-In / Apple Sign-In — optional authentication methods. We only receive basic profile info (name, email) from these providers.',
              ),
              LegalSection(
                title: '5. Data Storage & Security',
                body:
                    '• Your data is stored securely on Supabase servers using industry-standard encryption (TLS in transit, AES-256 at rest).\n\n'
                    '• We never store payment card details. All payment data is handled exclusively by Google Play or the App Store via RevenueCat.\n\n'
                    '• Access to your data is restricted to authorised systems and personnel only.\n\n'
                    '• While we take reasonable precautions, no method of electronic storage is 100% secure.',
              ),
              LegalSection(
                title: '6. Data Retention',
                body:
                    '• Your data is retained for as long as your Gowai account remains active.\n\n'
                    '• If you delete your account, all your personal data, profile information, and saved trips are permanently removed from our servers.\n\n'
                    '• You can delete your account at any time from Profile → Delete Account.',
              ),
              LegalSection(
                title: '7. Children\'s Privacy',
                body:
                    'Gowai is not intended for users under the age of 13. We do not knowingly collect personal information from children under 13. '
                    'If you believe a child has provided us with personal information, please contact us immediately at gowai.app@gmail.com and we will delete it promptly.',
              ),
              LegalSection(
                title: '8. Your Rights',
                body: 'You have the following rights regarding your data:\n\n'
                    '• Access — you can view your profile and all trip data within the app at any time.\n\n'
                    '• Deletion — you can permanently delete all your data by using the Delete Account feature in Profile settings.\n\n'
                    '• Correction — you can update your profile information within the app.\n\n'
                    '• Contact — for any data-related requests or questions, email us at gowai.app@gmail.com.',
              ),
              LegalSection(
                title: '9. Changes to This Policy',
                body:
                    'We may update this Privacy Policy from time to time. When we do, we will update the "Last Updated" date at the top of this page. '
                    'Your continued use of Gowai after any changes to this policy constitutes your acceptance of the updated terms.',
              ),
              LegalSection(
                title: '10. Contact Us',
                body:
                    'If you have any questions about this Privacy Policy or how we handle your data, please contact us:\n\n'
                    'Spotroot Technology LLP\n'
                    'Email: gowai.app@gmail.com\n'
                    'Website: gowai.app',
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// Section/badge widgets live in widgets/legal_section.dart (shared with
// the Terms of Service screen).
