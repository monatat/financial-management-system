import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../../core/widgets/money_text.dart';

// ── Shared mini donut ─────────────────────────────────────────────────────────

/// Thin donut-ring progress indicator built with [PieChart].
///
/// [progress] is a ratio (0.0 – 1.0+). Values above 1.0 are clamped for the
/// ring fill; the centre label still shows the actual percentage.
class _MiniDonut extends StatelessWidget {
  const _MiniDonut({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final pct = progress * 100; // display percentage (may exceed 100)
    final filled = clamped * 100;
    final empty = 100 - filled;

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: filled,
                  color: color,
                  radius: 9,
                  title: '',
                ),
                PieChartSectionData(
                  value: empty > 0 ? empty : 0,
                  color: color.withValues(alpha: 0.12),
                  radius: 9,
                  title: '',
                ),
              ],
              centerSpaceRadius: 27,
              sectionsSpace: 0,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
          Text(
            pct >= 100
                ? '${pct.toStringAsFixed(0)}%'
                : '${pct.toStringAsFixed(0)}%',
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.donut,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Widget donut;
  final Widget primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card label row
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.caption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Donut + value side-by-side
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    primary,
                    const SizedBox(height: 2),
                    Text(
                      secondary,
                      style: AppTypography.caption.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Spending Card
// ─────────────────────────────────────────────────────────────────────────────

/// Shows this month's expense as a percentage of income.
/// Data comes from [DashboardSummaryModel] already available on the dashboard.
class DashboardSpendingMiniCard extends StatelessWidget {
  const DashboardSpendingMiniCard({
    super.key,
    required this.totalExpense,
    required this.totalIncome,
    required this.currency,
  });

  final double totalExpense;
  final double totalIncome;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ratio = totalIncome > 0 ? totalExpense / totalIncome : 0.0;
    final isOverSpent = ratio > 1.0;

    return _AnalyticsCard(
      label: 'Spending',
      icon: Icons.arrow_downward_rounded,
      iconColor: AppColors.danger,
      donut: _MiniDonut(progress: ratio, color: AppColors.danger),
      primary: MoneyText(
        amount: totalExpense,
        currency: currency,
        variant: MoneyVariant.small,
        color: AppColors.danger,
      ),
      secondary: totalIncome > 0
          ? (isOverSpent ? 'Over income' : 'of income')
          : 'this month',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Budget Health Card
// ─────────────────────────────────────────────────────────────────────────────

/// Shows total budget spent vs allocated for the current month.
/// Data: [budgetSpent] and [budgetAllocated] already computed in both dashboards.
class DashboardBudgetMiniCard extends StatelessWidget {
  const DashboardBudgetMiniCard({
    super.key,
    required this.spent,
    required this.allocated,
    required this.currency,
  });

  final double spent;
  final double allocated;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ratio = allocated > 0 ? spent / allocated : 0.0;
    final color =
        ratio > 1.0 ? AppColors.danger : AppColors.warning;
    final hasData = allocated > 0;

    return _AnalyticsCard(
      label: 'Budget',
      icon: Icons.pie_chart_rounded,
      iconColor: color,
      donut: hasData
          ? _MiniDonut(progress: ratio, color: color)
          : _MiniDonut(progress: 0, color: AppColors.textDisabled),
      primary: hasData
          ? MoneyText(
              amount: spent,
              currency: currency,
              variant: MoneyVariant.small,
              color: color,
            )
          : Builder(
              builder: (context) => Text(
                'Not set',
                style: AppTypography.label.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38)),
              ),
            ),
      secondary: hasData
          ? (ratio > 1.0
              ? 'Over budget'
              : '${(ratio * 100).toStringAsFixed(0)}% used')
          : 'No budgets this month',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Savings Progress Card
// ─────────────────────────────────────────────────────────────────────────────

/// Shows total saved vs total goal target.
/// Data: [goalSaved] and [goalTarget] already computed in both dashboards.
class DashboardSavingsMiniCard extends StatelessWidget {
  const DashboardSavingsMiniCard({
    super.key,
    required this.saved,
    required this.target,
    required this.currency,
  });

  final double saved;
  final double target;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? saved / target : 0.0;
    final hasData = target > 0;

    return _AnalyticsCard(
      label: 'Savings',
      icon: Icons.savings_rounded,
      iconColor: AppColors.success,
      donut: hasData
          ? _MiniDonut(progress: ratio, color: AppColors.success)
          : _MiniDonut(progress: 0, color: AppColors.textDisabled),
      primary: hasData
          ? MoneyText(
              amount: saved,
              currency: currency,
              variant: MoneyVariant.small,
              color: AppColors.success,
            )
          : Builder(
              builder: (context) => Text(
                'No goals',
                style: AppTypography.label.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38)),
              ),
            ),
      secondary: hasData
          ? '${(ratio * 100).toStringAsFixed(0)}% of target'
          : 'Set a saving goal',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Debt Progress Card
// ─────────────────────────────────────────────────────────────────────────────

/// Shows total debt repaid vs total debt.
/// Data: [debtRepaid] and [debtTotal] already computed in both dashboards.
///
/// When [debtTotal] == 0 the user is debt-free — shown as 100% complete.
class DashboardDebtMiniCard extends StatelessWidget {
  const DashboardDebtMiniCard({
    super.key,
    required this.repaid,
    required this.total,
    required this.currency,
  });

  final double repaid;
  final double total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final hasDebt = total > 0;
    final ratio = hasDebt ? (repaid / total).clamp(0.0, 1.0) : 1.0;

    return _AnalyticsCard(
      label: 'Debt',
      icon: Icons.account_balance_rounded,
      iconColor: AppColors.primary,
      donut: _MiniDonut(progress: ratio, color: AppColors.primary),
      primary: hasDebt
          ? MoneyText(
              amount: total - repaid,
              currency: currency,
              variant: MoneyVariant.small,
              color: AppColors.primary,
            )
          : Text(
              'Debt-free!',
              style: AppTypography.label
                  .copyWith(color: AppColors.success),
            ),
      secondary: hasDebt
          ? '${(ratio * 100).toStringAsFixed(0)}% repaid'
          : 'No debts tracked',
    );
  }
}
