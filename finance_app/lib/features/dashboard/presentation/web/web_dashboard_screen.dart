import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/responsive/responsive_helpers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fintech_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../budget/presentation/budget_provider.dart';
import '../../../debts/presentation/debt_provider.dart';
import '../../../leftover_allocator/presentation/leftover_popup.dart';
import '../../../leftover_allocator/presentation/sweep_provider.dart';
import '../../../saving_goals/presentation/saving_goal_provider.dart';
import '../../../../core/widgets/health_score_card.dart';
import '../dashboard_analytics_cards.dart';
import '../dashboard_quick_actions.dart';
import '../../../transactions/domain/transaction_model.dart';
import '../../../transactions/presentation/add_transaction_screen.dart';
import '../../../transactions/presentation/edit_transaction_screen.dart';
import '../dashboard_provider.dart';

class WebDashboardScreen extends ConsumerStatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  ConsumerState<WebDashboardScreen> createState() =>
      _WebDashboardScreenState();
}

class _WebDashboardScreenState extends ConsumerState<WebDashboardScreen> {
  bool _sweepChecked = false;

  static const _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSweep());
  }

  Future<void> _checkSweep() async {
    if (_sweepChecked) return;
    _sweepChecked = true;

    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;

    try {
      await ref.read(sweepServiceProvider).createPendingSweepIfNeeded(uid);
      final pending =
          await ref.read(sweepServiceProvider).checkPendingSweep(uid);

      if (pending != null && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => LeftoverPopup(
            sweep: pending,
            uid: uid,
            // Popup closes itself — onDone is a no-op here.
            onDone: () {},
          ),
        );
      }
    } catch (_) {
      // Sweep check is non-critical — silently ignore failures
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(currentMonthDashboardProvider);
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ?? 'MYR';
    final now = DateTime.now();
    final monthLabel = '${_monthNames[now.month]} ${now.year}';

    // ── Health score inputs ─────────────────────────────────────────────────
    final goals = ref.watch(goalsProvider).asData?.value ?? [];
    final debts = ref.watch(debtsProvider).asData?.value ?? [];
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final budgets =
        ref.watch(budgetsWithSpendingProvider(monthKey)).asData?.value ?? [];

    final goalTarget = goals.fold<double>(0, (s, g) => s + g.targetAmount);
    final goalSaved = goals.fold<double>(0, (s, g) => s + g.savedAmount);
    final debtTotal = debts.fold<double>(0, (s, d) => s + d.totalAmount);
    final debtRemaining = debts.fold<double>(0, (s, d) => s + d.remainingAmount);
    final budgetAllocated = budgets.fold<double>(0, (s, b) => s + b.budget.allocatedAmount);
    final budgetSpent = budgets.fold<double>(0, (s, b) => s + b.spentAmount);
    final totalIncome = summaryAsync.asData?.value.totalIncome ?? 0.0;

    final healthScore = calculateHealthScore(
      budgetUsagePercent: budgetAllocated > 0 ? budgetSpent / budgetAllocated : 0,
      hasBudgets: budgetAllocated > 0,
      savingsProgressPercent: goalTarget > 0 ? goalSaved / goalTarget : 0,
      debtRepaidPercent: debtTotal > 0 ? (debtTotal - debtRemaining) / debtTotal : 1.0,
      hasDebts: debtTotal > 0,
      invisibleLeakageAmount: 0,
      totalIncome: totalIncome,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics Dashboard'),
            Text(
              monthLabel,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Transaction'),
            ),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 26,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Check your connection and try again.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.responsiveMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 4 KPI cards ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.arrow_upward_rounded,
                        iconColor: AppColors.success,
                        title: 'Income',
                        valueWidget: MoneyText(
                          amount: summary.totalIncome,
                          currency: currency,
                          variant: MoneyVariant.large,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.arrow_downward_rounded,
                        iconColor: AppColors.danger,
                        title: 'Expense',
                        valueWidget: MoneyText(
                          amount: summary.totalExpense,
                          currency: currency,
                          variant: MoneyVariant.large,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        icon: summary.isBalancePositive
                            ? Icons.account_balance_wallet_rounded
                            : Icons.warning_rounded,
                        iconColor: summary.isBalancePositive
                            ? AppColors.primary
                            : AppColors.danger,
                        title: 'Balance',
                        valueWidget: MoneyText(
                          amount: summary.balance.abs(),
                          currency: currency,
                          variant: MoneyVariant.large,
                          color: summary.isBalancePositive
                              ? AppColors.primary
                              : AppColors.danger,
                        ),
                        subtitle: summary.isBalancePositive ? 'Positive' : 'Deficit',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.info,
                        title: 'Transactions',
                        value: summary.transactionCount.toString(),
                        subtitle: 'this month',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Quick Actions ─────────────────────────────────────────────
                const DashboardQuickActions(),
                const SizedBox(height: AppSpacing.xl),

                // ── Analytics mini cards ──────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DashboardSpendingMiniCard(
                        totalExpense: summary.totalExpense,
                        totalIncome: summary.totalIncome,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardBudgetMiniCard(
                        spent: budgetSpent,
                        allocated: budgetAllocated,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardSavingsMiniCard(
                        saved: goalSaved,
                        target: goalTarget,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardDebtMiniCard(
                        repaid: debtTotal - debtRemaining,
                        total: debtTotal,
                        currency: currency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Main content row ─────────────────────────────────────────
                // Left: Health + Top Category + Budget Progress
                // Right: Saving Goals + Debt + Recent Transactions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Left column ─────────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          HealthScoreCard(
                            score: healthScore,
                            totalIncome: totalIncome,
                            totalExpense: summary.totalExpense,
                            budgetSpent: budgetSpent,
                            budgetAllocated: budgetAllocated,
                            debtOutstanding: debtRemaining,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          if (summary.topExpenseCategoryName != null) ...[
                            _TopCategoryWebCard(
                              name: summary.topExpenseCategoryName!,
                              amount: summary.topExpenseCategoryAmount,
                              currency: currency,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ] else ...[
                            _NoExpensesCard(),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          _DashBudgetCard(
                            budgets: budgets,
                            currency: currency,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),

                    // ── Right column ─────────────────────────────────────────
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // Saving Goals
                          _DashGoalsCard(
                            goals: goals,
                            goalTarget: goalTarget,
                            goalSaved: goalSaved,
                            currency: currency,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Debt / PTPTN
                          _DashDebtCard(
                            debts: debts,
                            debtTotal: debtTotal,
                            debtRemaining: debtRemaining,
                            currency: currency,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Recent Transactions
                          FintechCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionHeader(
                                  title: 'Recent Transactions',
                                  actionLabel: 'View All',
                                  onAction: () =>
                                      context.go(RouteNames.transactions),
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                if (!summary.hasTransactions)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.xxl),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.textDisabled
                                                .withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.receipt_long_outlined,
                                            size: 26,
                                            color: AppColors.textDisabled,
                                          ),
                                        ),
                                        const SizedBox(
                                            height: AppSpacing.md),
                                        Text(
                                          'No transactions this month',
                                          style: AppTypography.label
                                              .copyWith(
                                                  color: AppColors
                                                      .textSecondary),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add a transaction to get started.',
                                          style: AppTypography.caption
                                              .copyWith(
                                                  color: AppColors
                                                      .textDisabled),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...summary.recentTransactions
                                      .expand((tx) => [
                                            if (tx !=
                                                summary.recentTransactions
                                                    .first)
                                              const Divider(
                                                height: 1,
                                                indent: 56,
                                                color: AppColors.border,
                                              ),
                                            _WebTransactionRow(
                                              transaction: tx,
                                              currency: currency,
                                              onTap: () => Navigator.of(
                                                      context)
                                                  .push<void>(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      EditTransactionScreen(
                                                          transaction: tx),
                                                ),
                                              ),
                                            ),
                                          ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top category card (web) ───────────────────────────────────────────────────

class _TopCategoryWebCard extends StatelessWidget {
  const _TopCategoryWebCard({
    required this.name,
    required this.amount,
    required this.currency,
  });

  final String name;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top Spending Category',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(name,
                    style: AppTextStyles.titleLarge,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MoneyText(
            amount: amount,
            currency: currency,
            variant: MoneyVariant.normal,
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _NoExpensesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.textDisabled,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top Spending Category',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text('No expense data yet',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textDisabled)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard summary cards (real data) ──────────────────────────────────────

class _DashBudgetCard extends StatelessWidget {
  const _DashBudgetCard({required this.budgets, required this.currency});

  final List<dynamic> budgets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final allocated = budgets.fold<double>(0, (s, b) => s + (b.budget.allocatedAmount as double));
    final spent = budgets.fold<double>(0, (s, b) => s + (b.spentAmount as double));
    final remaining = allocated - spent;
    final isOver = spent > allocated && allocated > 0;
    final pct = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
    final pctLabel = allocated > 0
        ? '${(spent / allocated * 100).toStringAsFixed(0)}% used'
        : '';
    final color = isOver ? AppColors.expense : AppColors.warning;

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.pie_chart_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Text('Budget Progress', style: AppTextStyles.titleMedium),
          const Spacer(),
          if (pctLabel.isNotEmpty)
            Text(pctLabel,
                style: AppTextStyles.bodySmall
                    .copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (budgets.isEmpty)
          Text('No budgets set for this month.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))
        else ...[
          _DashProgressRow('Allocated',
              '$currency ${allocated.toStringAsFixed(2)}',
              AppColors.textSecondary),
          const SizedBox(height: 4),
          _DashProgressRow(
              'Spent', '$currency ${spent.toStringAsFixed(2)}', color),
          const SizedBox(height: 4),
          _DashProgressRow(
            isOver ? 'Over by' : 'Remaining',
            '$currency ${remaining.abs().toStringAsFixed(2)}',
            isOver ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 6),
            Text('⚠ Over budget this month',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger, fontWeight: FontWeight.w500)),
          ],
        ],
      ]),
    );
  }
}

class _DashGoalsCard extends StatelessWidget {
  const _DashGoalsCard({
    required this.goals,
    required this.goalTarget,
    required this.goalSaved,
    required this.currency,
  });

  final List<dynamic> goals;
  final double goalTarget;
  final double goalSaved;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final active = goals.where((g) => !(g.isCompleted as bool)).length;
    final completed = goals.where((g) => g.isCompleted as bool).length;
    final pct = goalTarget > 0
        ? (goalSaved / goalTarget).clamp(0.0, 1.0)
        : 0.0;

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.savings_rounded, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text('Saving Goals', style: AppTextStyles.titleMedium),
          const Spacer(),
          Text('${(pct * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.success, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (goals.isEmpty)
          Text('No saving goals yet.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))
        else ...[
          _DashProgressRow('Target',
              '$currency ${goalTarget.toStringAsFixed(2)}',
              AppColors.textSecondary),
          const SizedBox(height: 4),
          _DashProgressRow('Saved',
              '$currency ${goalSaved.toStringAsFixed(2)}', AppColors.success),
          const SizedBox(height: 4),
          _DashProgressRow(
            'Active goals',
            '$active active · $completed completed',
            AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: AppColors.success,
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
            ),
          ),
        ],
      ]),
    );
  }
}

class _DashDebtCard extends StatelessWidget {
  const _DashDebtCard({
    required this.debts,
    required this.debtTotal,
    required this.debtRemaining,
    required this.currency,
  });

  final List<dynamic> debts;
  final double debtTotal;
  final double debtRemaining;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final paid = debtTotal - debtRemaining;
    final active = debts.where((d) => !(d.isSettled as bool)).length;
    final pct = debtTotal > 0
        ? (paid / debtTotal).clamp(0.0, 1.0)
        : 0.0;

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.account_balance_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text('Debt / PTPTN', style: AppTextStyles.titleMedium),
          const Spacer(),
          Text('${(pct * 100).toStringAsFixed(0)}% repaid',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        if (debts.isEmpty)
          Text('No debts tracked.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary))
        else ...[
          _DashProgressRow('Total',
              '$currency ${debtTotal.toStringAsFixed(2)}',
              AppColors.textSecondary),
          const SizedBox(height: 4),
          _DashProgressRow(
              'Paid', '$currency ${paid.toStringAsFixed(2)}', AppColors.success),
          const SizedBox(height: 4),
          _DashProgressRow(
              'Remaining',
              '$currency ${debtRemaining.toStringAsFixed(2)}',
              debtRemaining > 0 ? AppColors.danger : AppColors.success),
          const SizedBox(height: 4),
          _DashProgressRow(
              'Active debts',
              '$active debt${active == 1 ? '' : 's'}',
              AppColors.textSecondary),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ]),
    );
  }
}

class _DashProgressRow extends StatelessWidget {
  const _DashProgressRow(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.bodySmall),
      Text(value,
          style: AppTextStyles.bodySmall.copyWith(
              color: valueColor, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ── Web transaction row ───────────────────────────────────────────────────────

class _WebTransactionRow extends StatelessWidget {
  const _WebTransactionRow({
    required this.transaction,
    required this.currency,
    required this.onTap,
  });

  final TransactionModel transaction;
  final String currency;
  final VoidCallback onTap;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final color = isIncome ? AppColors.success : AppColors.danger;
    final d = transaction.date;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            // ── Category badge ─────────────────────────────────────────
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 16,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Centre: title + category · date ────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    style: AppTypography.label.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        transaction.categoryName,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ' · ${d.day} ${_months[d.month]}',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textDisabled),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Right: amount ──────────────────────────────────────────
            MoneyText(
              amount: isIncome
                  ? transaction.amount
                  : -transaction.amount,
              currency: currency,
              showSign: isIncome,
              variant: MoneyVariant.small,
              color: color,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
