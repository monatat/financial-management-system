import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../budget/presentation/budget_form_screen.dart';
import '../../debts/presentation/debt_form_screen.dart';
import '../../saving_goals/presentation/saving_goal_form_screen.dart';
import '../../transactions/presentation/add_transaction_screen.dart';

// ── Dashboard Quick Actions ───────────────────────────────────────────────────

/// A responsive grid of four "Add …" shortcuts.
///
/// • Mobile / narrow (available width < 500 dp): 2 × 2 grid.
/// • Tablet / desktop (≥ 500 dp): single row of 4.
///
/// All navigation uses [Navigator.push] with [MaterialPageRoute] so it matches
/// the existing pattern used throughout the app.  No new routes are defined.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  /// Current month key in "YYYY-MM" format, required by [BudgetFormScreen].
  static String _monthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTypography.label.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6)),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 500;

              final tiles = [
                _QuickActionTile(
                  icon: Icons.add_card_rounded,
                  label: 'Add\nTransaction',
                  color: AppColors.success,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(),
                    ),
                  ),
                ),
                _QuickActionTile(
                  icon: Icons.pie_chart_rounded,
                  label: 'Add\nBudget',
                  color: AppColors.warning,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          BudgetFormScreen(month: _monthKey()),
                    ),
                  ),
                ),
                _QuickActionTile(
                  icon: Icons.savings_rounded,
                  label: 'Add\nGoal',
                  color: AppColors.primary,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const SavingGoalFormScreen(),
                    ),
                  ),
                ),
                _QuickActionTile(
                  icon: Icons.account_balance_rounded,
                  label: 'Add\nDebt',
                  color: AppColors.danger,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const DebtFormScreen(),
                    ),
                  ),
                ),
              ];

              if (isWide) {
                // ── Single row (tablet / desktop) ─────────────────────────
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              }

              // ── 2 × 2 grid (mobile / narrow) ──────────────────────────
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: tiles[2]),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: tiles[3]),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Quick action tile ─────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Label
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
