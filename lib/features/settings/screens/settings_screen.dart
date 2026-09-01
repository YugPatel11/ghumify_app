import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTokens.sm),
              Text('Profile', style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: AppTokens.xl),

              // ── Profile Card ──
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(AppTokens.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    boxShadow: AppTokens.coloredShadow(AppColors.brand, level: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppTokens.xl),

              // ── Quick Actions ──
              _buildSectionLabel('QUICK ACTIONS'),
              const SizedBox(height: AppTokens.md),
              _buildSettingsGroup(
                context,
                children: [
                  _SettingsTile(
                    icon: Icons.auto_awesome,
                    iconColor: AppColors.brand,
                    title: 'Plan a Trip',
                    onTap: () => context.push('/plan-trip'),
                  ),
                  _SettingsTile(
                    icon: Icons.translate_rounded,
                    iconColor: AppColors.accentDeep,
                    title: 'Translator',
                    onTap: () => context.push('/translator'),
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.bookmark_outline_rounded,
                    iconColor: AppColors.info,
                    title: 'Saved Trips',
                    onTap: () => context.push('/saved-itineraries'),
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.explore_outlined,
                    iconColor: AppColors.success,
                    title: 'Discover Places',
                    onTap: () => context.go('/discover'),
                    showDivider: true,
                  ),
                ],
              ),

              const SizedBox(height: AppTokens.xl),

              // ── Preferences ──
              _buildSectionLabel('PREFERENCES'),
              const SizedBox(height: AppTokens.md),
              _buildSettingsGroup(
                context,
                children: [
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    iconColor: AppColors.brand,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: AppTokens.xl),

              // ── About ──
              _buildSectionLabel('ABOUT GHUMIFY'),
              const SizedBox(height: AppTokens.md),
              _buildSettingsGroup(
                context,
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textSoft,
                    title: 'Version',
                    subtitle: '1.0.0',
                  ),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: AppColors.textSoft,
                    title: 'Terms of Service',
                    onTap: () {},
                    showDivider: true,
                  ),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: AppColors.textSoft,
                    title: 'Privacy Policy',
                    onTap: () {},
                    showDivider: true,
                  ),
                ],
              ),

              if (user != null) ...[
                const SizedBox(height: AppTokens.xxl),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await authProvider.signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(BuildContext context, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 60, color: AppColors.border),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                )
              : null,
          trailing: onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20)
              : null,
          onTap: onTap,
        ),
      ],
    );
  }
}
