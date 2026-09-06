import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_page.dart';
import '../../../core/utils/icon_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/presentation/category_provider.dart';
import '../domain/budget_with_spending_model.dart';
import 'budget_form_screen.dart';
import 'budget_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  // ── Month helpers ──────────────────────────────────────────────────────────

  static const _monthNames = [
    '',
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String get _monthKey =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  String get _monthLabel =>
      '${_monthNames[_currentMonth.month]} ${_currentMonth.year}';

  void _previousMonth() =>
      setState(() => _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1));

  void _nextMonth() {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final now = DateTime.now();
    if (next.year < now.year ||
        (next.year == now.year && next.month <= now.month)) {
      setState(() => _currentMonth = next);
    }
  }

  bool get _canGoNext {
    final next = DateTime(_currentMonth.year, _currentMonth.month + 1);
    final now = DateTime.now();
    return next.year < now.year ||
        (next.year == now.year && next.month <= now.month);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openAddBudget() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => BudgetFormScreen(month: _monthKey),
    ));
  }

  void _openEditBudget(BudgetWithSpendingModel entry) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => BudgetFormScreen(
        month: entry.budget.month,
        existingBudget: entry.budget,
      ),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsWithSpendingProvider(_monthKey));
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

    // Build a lookup map: categoryId → CategoryModel for icon/colour display
    final categoryMap = Map<String, CategoryModel>.fromEntries(
      (categoriesAsync.asData?.value ?? [])
          .map((c) => MapEntry(c.categoryId, c)),
    );

    return Scaffold(
      appBar: AppBar(
        title: _MonthNavigator(
          label: _monthLabel,
          onPrevious: _previousMonth,
          onNext: _nextMonth,
          canGoNext: _canGoNext,
        ),
        centerTitle: true,
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load budgets',
              style: AppTextStyles.bodyMedium),
        ),
        data: (budgets) => ResponsiveContent(child: Column(
          children: [
            // ── Summary row ────────────────────────────────────────────────
            _SummaryRow(budgets: budgets, currency: currency),
            const Divider(height: 1),

            // ── Budget list ────────────────────────────────────────────────
            Expanded(
              child: budgets.isEmpty
                  ? EmptyState(
                      title: 'No budgets for $_monthLabel',
                      subtitle:
                          'Tap + to set a spending limit for a category.',
                      icon: Icons.pie_chart_outline_rounded,
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: budgets.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _BudgetCard(
                        entry: budgets[i],
                        category: categoryMap[budgets[i].budget.categoryId],
                        currency: currency,
                        onTap: () => _openEditBudget(budgets[i]),
                      ),
                    ),
            ),
          ],
        ),),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBudget,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Budget'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Month navigator ───────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.canGoNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrevious,
          tooltip: 'Previous month',
        ),
        Text(label, style: AppTextStyles.titleLarge),
        IconButton(
          icon: Icon(
            Icons.chevron_right_rounded,
            color: canGoNext ? null : AppColors.textDisabled,
          ),
          onPressed: canGoNext ? onNext : null,
          tooltip: 'Next month',
        ),
      ],
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.budgets, required this.currency});

  final List<BudgetWithSpendingModel> budgets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final totalBudget = budgets.fold<double>(
        0.0, (t, b) => t + b.budget.allocatedAmount);
    final totalSpent =
        budgets.fold<double>(0.0, (t, b) => t + b.spentAmount);
    final totalRemaining = totalBudget - totalSpent;
    final anyOverspent = budgets.any((b) => b.isOverspent);

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Budget',
            value: '$currency ${totalBudget.toStringAsFixed(2)}',
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Spent',
            value: '$currency ${totalSpent.toStringAsFixed(2)}',
            color: anyOverspent ? AppColors.expense : AppColors.warning,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            label: 'Remaining',
            value: '$currency ${totalRemaining.abs().toStringAsFixed(2)}',
            color: totalRemaining >= 0
                ? AppColors.income
                : AppColors.expense,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? _chipDarkBg(color) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? _chipDarkBorder(color)
                : color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppTextStyles.labelSmall.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary chip dark-mode helpers ───────────────────────────────────────────

Color _chipDarkBg(Color color) {
  if (color == AppColors.success) return const Color(0xFF10261A);
  if (color == AppColors.danger) return const Color(0xFF2A1515);
  if (color == AppColors.primary) return const Color(0xFF15213B);
  if (color == AppColors.warning) return const Color(0xFF271F0A);
  return color.withValues(alpha: 0.12);
}

Color _chipDarkBorder(Color color) {
  if (color == AppColors.success) return const Color(0xFF22C55E);
  if (color == AppColors.danger) return const Color(0xFFEF4444);
  if (color == AppColors.primary) return const Color(0xFF60A5FA);
  if (color == AppColors.warning) return const Color(0xFFF59E0B);
  return color;
}

// ── Budget card ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.entry,
    required this.category,
    required this.currency,
    required this.onTap,
  });

  final BudgetWithSpendingModel entry;
  final CategoryModel? category;
  final String currency;
  final VoidCallback onTap;

  Color get _progressColor {
    if (entry.isOverspent) return AppColors.expense;
    if (entry.usagePercent >= 0.75) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final iconCode =
        cat?.iconCode ?? Icons.category_rounded.codePoint;
    final iconColor = cat?.color ?? AppColors.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      materialIconData(iconCode),
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.budget.categoryName,
                            style: AppTextStyles.titleMedium),
                        Text(
                          'Budget: $currency '
                          '${entry.budget.allocatedAmount.toStringAsFixed(2)}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Usage percentage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _progressColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.percentLabel,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: _progressColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Progress bar ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.clampedPercent,
                  backgroundColor:
                      _progressColor.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),

              // ── Spent / Remaining row ────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent: $currency '
                    '${entry.spentAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    entry.isOverspent
                        ? 'Over by: $currency '
                            '${entry.remainingAmount.abs().toStringAsFixed(2)}'
                        : 'Left: $currency '
                            '${entry.remainingAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: entry.isOverspent
                          ? AppColors.expense
                          : AppColors.textSecondary,
                      fontWeight: entry.isOverspent
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),

              // ── Overspent warning ────────────────────────────────────────
              if (entry.isOverspent) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            AppColors.expense.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.expense, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Overspending! You exceeded this budget.',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.expense, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
