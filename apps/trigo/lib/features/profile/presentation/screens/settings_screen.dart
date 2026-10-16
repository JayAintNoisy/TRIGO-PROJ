import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_release.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 24),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    bool showToggle = false,
    bool toggleValue = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: showToggle ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        trailing: showToggle
            ? Switch(
                value: toggleValue,
                onChanged: (val) {},
                activeTrackColor: const Color(0xFF3B82F6),
                activeColor: Colors.white,
              )
            : Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const AppTopBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('ACCOUNT'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            iconColor: const Color(0xFF3B82F6), // blue-500
            bgColor: const Color(0xFFEFF6FF), // blue-50
            title: 'Personal Information',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.lock_outline,
            iconColor: const Color(0xFFF59E0B), // amber-500
            bgColor: const Color(0xFFFEF3C7), // amber-50
            title: 'Change Password',
            onTap: () {},
          ),

          _buildSectionHeader('PREFERENCES'),
          _buildSettingsTile(
            icon: Icons.notifications_none,
            iconColor: const Color(0xFF10B981), // emerald-500
            bgColor: const Color(0xFFECFDF5), // emerald-50
            title: 'Push Notifications',
            showToggle: true,
            toggleValue: true,
          ),
          _buildSettingsTile(
            icon: Icons.location_on_outlined,
            iconColor: const Color(0xFF8B5CF6), // violet-500
            bgColor: const Color(0xFFF5F3FF), // violet-50
            title: 'Location Services',
            showToggle: true,
            toggleValue: true,
          ),

          _buildSectionHeader('ABOUT'),
          _buildSettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: Colors.grey.shade600,
            bgColor: Colors.grey.shade100,
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            iconColor: Colors.grey.shade600,
            bgColor: Colors.grey.shade100,
            title: 'Terms of Service',
            onTap: () {},
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2), // red-100
                foregroundColor: const Color(0xFFEF4444), // red-500
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _buildReleaseFooter()),
        ],
      ),
    );
  }

  /// Env-driven build identity footer: muted 12px text for production, or the
  /// same amber release-channel pill used on the splash screen.
  Widget _buildReleaseFooter() {
    final text = 'TriGo v${AppReleaseInfo.display}';
    if (AppReleaseInfo.isProduction) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }
}
