import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/settings/appearance_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/presentation/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authServiceProvider).logout();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.asData?.value;

    // Read the saved currency from the Firestore profile (read-only display).
    final profileAsync = ref.watch(currentUserProfileProvider);
    final currentCurrency =
        profileAsync.asData?.value?.currency ?? AppStrings.defaultCurrency;

    if (_isLoggingOut) {
      return const Center(child: CircularProgressIndicator());
    }

    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: context.contentHorizontalPadding,
        vertical: 16,
      ),
      children: [
        // ── Account card ─────────────────────────────────────────────────
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cs.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person_rounded,
                  size: 30,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'My Account',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Account settings ──────────────────────────────────────────────
        Text('Account',
            style: AppTextStyles.labelLarge
                .copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _DarkModeRow(
          isDark: ref.watch(appearanceProvider),
          onChanged: (v) {
            ref.read(appearanceProvider.notifier).setDarkMode(v);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dark Mode ${v ? 'enabled' : 'disabled'}.'),
              ),
            );
          },
        ),
        const SizedBox(height: 8),

        // Currency row — read-only; set once during first-time setup
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.currency_exchange_rounded,
                  size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Default Currency ($currentCurrency)',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This is your account base currency and is set during first setup.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // No chevron — not clickable
              Icon(Icons.lock_outline_rounded,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.38)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onTap: () {},
        ),
        const SizedBox(height: 24),

        // ── Support ───────────────────────────────────────────────────────
        Text('Support',
            style: AppTextStyles.labelLarge
                .copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          label: 'Help & FAQ',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _MenuItem(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () {},
        ),
        const SizedBox(height: 24),

        // ── Logout ────────────────────────────────────────────────────────
        _MenuItem(
          icon: Icons.logout_rounded,
          label: AppStrings.logout,
          color: AppColors.expense,
          onTap: _logout,
        ),
      ],
    );
  }
}

// ── Dark Mode row ─────────────────────────────────────────────────────────────

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow({
    required this.isDark,
    required this.onChanged,
  });

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: 10),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            size: 20,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dark Mode', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'On' : 'Off',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final itemColor = color ?? cs.onSurface;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: itemColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: itemColor),
            ),
          ),
          if (color == null)
            Icon(Icons.chevron_right_rounded,
                size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }
}
