import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../app/theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settingsProvider = context.watch<AppSettingsProvider>();
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user != null) ...[
            _buildProfileCard(context, user, isDark),
            const SizedBox(height: 32),
          ],
          _buildSectionHeader('PREFERENCES'),
          const SizedBox(height: 16),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Toggle application theme',
                trailing: Switch.adaptive(
                  value: settingsProvider.themeMode == ThemeMode.dark ||
                      (settingsProvider.themeMode == ThemeMode.system && isDark),
                  onChanged: (val) {
                    settingsProvider.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),
              _buildDivider(),
              _buildSettingItem(
                context,
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: settingsProvider.language.toUpperCase(),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Show language picker
                  _showLanguagePicker(context, settingsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('SUPPORT'),
          const SizedBox(height: 16),
          _buildSettingsCard(
            isDark: isDark,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.help_outline,
                title: 'Help Center',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              _buildDivider(),
              _buildSettingItem(
                context,
                icon: Icons.info_outline,
                title: 'About Ghumify',
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, user, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primaryOrange).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person, size: 32, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Builder(
      builder: (context) {
        return Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.5,
              ),
        );
      }
    );
  }

  Widget _buildSettingsCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.neutral900.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 64, endIndent: 20);
  }

  void _showLanguagePicker(BuildContext context, AppSettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final languages = ['en', 'hi', 'gu', 'mr', 'bn', 'ta', 'te'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Language',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (ctx, idx) {
                    final lang = languages[idx];
                    return ListTile(
                      title: Text(lang.toUpperCase()),
                      trailing: provider.language == lang
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        provider.setLanguage(lang);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
