import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/fintech_card.dart';
import '../../../../core/widgets/health_score_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../dashboard_analytics_cards.dart';
import '../dashboard_quick_actions.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/progress_summary_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../budget/presentation/budget_provider.dart';
import '../../../debts/presentation/debt_provider.dart';
import '../../../leftover_allocator/presentation/leftover_popup.dart';
import '../../../leftover_allocator/presentation/sweep_provider.dart';
import '../../../saving_goals/presentation/saving_goal_provider.dart';
import '../../../transactions/domain/transaction_model.dart';
import '../../../transactions/presentation/add_transaction_screen.dart';
import '../../../transactions/presentation/edit_transaction_screen.dart';
import '../dashboard_provider.dart';

class MobileDashboardScreen extends ConsumerStatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  ConsumerState<MobileDashboardScreen> createState() =>
      _MobileDashboardScreenState();
}

class _MobileDashboardScreenState
    extends ConsumerState<MobileDashboardScreen> {
  bool _sweepChecked = false;

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
    final profileAsync = ref.watch(currentUserProfileProvider);
    final currency = profileAsync.asData?.value?.currency ?? 'MYR';
    final userName = profileAsync.asData?.value?.name ?? '';

    // Health score + module summary inputs
    final goals = ref.watch(goalsProvider).asData?.value ?? [];
    final debts = ref.watch(debtsProvider).asData?.value ?? [];
    final now2 = DateTime.now();
    final monthKey2 =
        '${now2.year}-${now2.month.toString().padLeft(2, '0')}';
    final budgets =
        ref.watch(budgetsWithSpendingProvider(monthKey2)).asData?.value ?? [];

    final goalTarget = goals.fold<double>(0, (s, g) => s + g.targetAmount);
    final goalSaved = goals.fold<double>(0, (s, g) => s + g.savedAmount);
    final debtTotal = debts.fold<double>(0, (s, d) => s + d.totalAmount);
    final debtRemaining = debts.fold<double>(0, (s, d) => s + d.remainingAmount);
    final budgetAllocated =
        budgets.fold<double>(0, (s, b) => s + b.budget.allocatedAmount);
    final budgetSpent =
        budgets.fold<double>(0, (s, b) => s + b.spentAmount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_greeting()},',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            Text(
              userName.isNotEmpty ? userName : 'Welcome!',
              style: AppTextStyles.titleLarge,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _monthLabel(),
              style: AppTextStyles.labelLarge,
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
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('Could not load dashboard',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        data: (summary) {
          final score = calculateHealthScore(
            budgetUsagePercent:
                budgetAllocated > 0 ? budgetSpent / budgetAllocated : 0,
            hasBudgets: budgetAllocated > 0,
            savingsProgressPercent:
                goalTarget > 0 ? goalSaved / goalTarget : 0,
            debtRepaidPercent: debtTotal > 0
                ? (debtTotal - debtRemaining) / debtTotal
                : 1.0,
            hasDebts: debtTotal > 0,
            invisibleLeakageAmount: 0,
            totalIncome: summary.totalIncome,
          );
          return _Body(
            summary: summary,
            currency: currency,
            healthScore: score,
            budgets: budgets,
            budgetAllocated: budgetAllocated,
            budgetSpent: budgetSpent,
            goals: goals,
            goalTarget: goalTarget,
            goalSaved: goalSaved,
            debts: debts,
            debtTotal: debtTotal,
            debtRemaining: debtRemaining,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
              builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  static const _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthLabel() {
    final now = DateTime.now();
    return '${_monthNames[now.month]} ${now.year}';
  }
}

// ── Body (shown when data is available) ──────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({
    required this.summary,
    required this.currency,
    required this.healthScore,
    required this.budgets,
    required this.budgetAllocated,
    required this.budgetSpent,
    required this.goals,
    required this.goalTarget,
    required this.goalSaved,
    required this.debts,
    required this.debtTotal,
    required this.debtRemaining,
  });

  final dynamic summary;
  final String currency;
  final double healthScore;
  final List<dynamic> budgets;
  final double budgetAllocated;
  final double budgetSpent;
  final List<dynamic> goals;
  final double goalTarget;
  final double goalSaved;
  final List<dynamic> debts;
  final double debtTotal;
  final double debtRemaining;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Summary cards ──────────────────────────────────────────────────
        Row(
          children: [
            _SummaryCard(
              label: 'Income',
              amount: summary.totalIncome,
              currency: currency,
              color: AppColors.income,
              icon: Icons.arrow_upward_rounded,
            ),
            const SizedBox(width: 8),
            _SummaryCard(
              label: 'Expense',
              amount: summary.totalExpense,
              currency: currency,
              color: AppColors.expense,
              icon: Icons.arrow_downward_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _BalanceCard(
          balance: summary.balance,
          currency: currency,
          isPositive: summary.isBalancePositive,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Quick Actions ──────────────────────────────────────────────────
        const DashboardQuickActions(),
        const SizedBox(height: AppSpacing.md),

        // ── Financial Health Score ─────────────────────────────────────────
        HealthScoreCard(
          score: healthScore,
          compact: true,
          totalIncome: summary.totalIncome,
          totalExpense: summary.totalExpense,
          budgetSpent: budgetSpent,
          budgetAllocated: budgetAllocated,
          debtOutstanding: debtRemaining,
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Analytics mini cards (2 × 2 grid) ─────────────────────────────
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
            const SizedBox(width: 8),
            Expanded(
              child: DashboardBudgetMiniCard(
                spent: budgetSpent,
                allocated: budgetAllocated,
                currency: currency,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DashboardSavingsMiniCard(
                saved: goalSaved,
                target: goalTarget,
                currency: currency,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DashboardDebtMiniCard(
                repaid: debtTotal - debtRemaining,
                total: debtTotal,
                currency: currency,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Budget Progress ────────────────────────────────────────────────
        ProgressSummaryCard(
          title: 'Budget Progress',
          value: budgets.isEmpty
              ? '—'
              : '$currency ${budgetSpent.toStringAsFixed(2)} / ${budgetAllocated.toStringAsFixed(2)}',
          subtitle: budgets.isEmpty
              ? null
              : (budgetSpent > budgetAllocated
                  ? 'Over by $currency ${(budgetSpent - budgetAllocated).toStringAsFixed(2)}'
                  : '$currency ${(budgetAllocated - budgetSpent).toStringAsFixed(2)} remaining'),
          progress: budgetAllocated > 0
              ? (budgetSpent / budgetAllocated).clamp(0.0, 1.0)
              : 0.0,
          progressColor: budgetAllocated > 0 && budgetSpent > budgetAllocated
              ? AppColors.danger
              : AppColors.warning,
          statusText: budgets.isEmpty
              ? 'No budgets set for this month'
              : (budgetSpent > budgetAllocated
                  ? '⚠ Over budget'
                  : '${(budgetAllocated > 0 ? (budgetSpent / budgetAllocated * 100).clamp(0.0, 100.0) : 0.0).toStringAsFixed(0)}% used'),
          statusColor: budgetAllocated > 0 && budgetSpent > budgetAllocated
              ? AppColors.danger
              : null,
          padding: const EdgeInsets.all(14),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Saving Goals ───────────────────────────────────────────────────
        ProgressSummaryCard(
          title: 'Saving Goals',
          value: goals.isEmpty
              ? '—'
              : '$currency ${goalSaved.toStringAsFixed(2)} / ${goalTarget.toStringAsFixed(2)}',
          subtitle: goals.isEmpty
              ? null
              : '${goals.where((g) => !(g.isCompleted as bool)).length} active goal(s)',
          progress: goalTarget > 0
              ? (goalSaved / goalTarget).clamp(0.0, 1.0)
              : 0.0,
          progressColor: AppColors.success,
          statusText: goals.isEmpty
              ? 'No saving goals yet'
              : '${(goalTarget > 0 ? (goalSaved / goalTarget * 100).clamp(0.0, 100.0) : 0.0).toStringAsFixed(0)}% saved',
          padding: const EdgeInsets.all(14),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Debt / PTPTN ───────────────────────────────────────────────────
        ProgressSummaryCard(
          title: 'Debt / PTPTN',
          value: debts.isEmpty
              ? '—'
              : '$currency ${(debtTotal - debtRemaining).toStringAsFixed(2)} paid',
          subtitle: debts.isEmpty
              ? null
              : '$currency ${debtRemaining.toStringAsFixed(2)} remaining',
          progress: debtTotal > 0
              ? ((debtTotal - debtRemaining) / debtTotal).clamp(0.0, 1.0)
              : 0.0,
          progressColor: AppColors.primary,
          statusText: debts.isEmpty
              ? 'No debts tracked'
              : '${(debtTotal > 0 ? ((debtTotal - debtRemaining) / debtTotal * 100).clamp(0.0, 100.0) : 0.0).toStringAsFixed(0)}% repaid',
          padding: const EdgeInsets.all(14),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Top spending category ──────────────────────────────────────────
        if (summary.topExpenseCategoryName != null) ...[
          SectionHeader(title: 'Top Spending'),
          const SizedBox(height: 8),
          _TopCategoryCard(
            name: summary.topExpenseCategoryName!,
            amount: summary.topExpenseCategoryAmount,
            currency: currency,
          ),
          const SizedBox(height: 16),
        ],

        // ── Recent transactions ────────────────────────────────────────────
        SectionHeader(
          title: 'Recent Transactions',
          actionLabel: 'View All',
          onAction: () => context.go(RouteNames.transactions),
        ),
        const SizedBox(height: 8),

        if (!summary.hasTransactions)
          _EmptyTransactionsCard()
        else
          ...List.generate(
            summary.recentTransactions.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _RecentTransactionTile(
                transaction: summary.recentTransactions[i],
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => EditTransactionScreen(
                      transaction: summary.recentTransactions[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(
                amount: amount,
                currency: currency,
                variant: MoneyVariant.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.currency,
    required this.isPositive,
  });

  final double balance;
  final String currency;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.primary : AppColors.danger;

    return MetricCard(
      icon: isPositive
          ? Icons.account_balance_wallet_rounded
          : Icons.warning_rounded,
      iconColor: color,
      title: isPositive ? 'Available Balance' : 'Balance',
      valueWidget: MoneyText(
        amount: balance.abs(),
        currency: currency,
        variant: MoneyVariant.large,
        color: color,
      ),
      subtitle: isPositive ? 'Positive' : 'Deficit',
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── Top category card ─────────────────────────────────────────────────────────

class _TopCategoryCard extends StatelessWidget {
  const _TopCategoryCard({
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Top Spending', style: AppTextStyles.bodySmall),
                Text(name,
                    style: AppTextStyles.titleMedium,
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

// ── Empty state card ──────────────────────────────────────────────────────────

class _EmptyTransactionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FintechCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.textDisabled.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 26,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No transactions this month',
            style: AppTypography.label
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to record your first transaction.',
            style: AppTypography.caption
                .copyWith(color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Recent transaction tile ───────────────────────────────────────────────────

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({
    required this.transaction,
    required this.onTap,
  });

  final TransactionModel transaction;
  final VoidCallback onTap;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor =
        isIncome ? AppColors.success : AppColors.danger;
    final d = transaction.date;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: FintechCard(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 3),
        child: Row(
          children: [
            // ── Category badge ───────────────────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
                color: amountColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // ── Centre: title · category · date ─────────────────────────
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
                  Text(
                    transaction.categoryName,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${d.day} ${_months[d.month]} ${d.year}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // ── Right: amount ────────────────────────────────────────────
            MoneyText(
              amount: isIncome
                  ? transaction.amount
                  : -transaction.amount,
              currency: transaction.currency,
              showSign: isIncome,
              variant: MoneyVariant.small,
              color: amountColor,
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}


