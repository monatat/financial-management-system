import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/router/route_names.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/fintech_card.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../debts/presentation/debt_provider.dart';
import '../../saving_goals/presentation/saving_goal_provider.dart';
import '../domain/category_spending_model.dart';
import '../domain/financial_summary_model.dart';
import '../domain/monthly_trend_model.dart';
import 'report_provider.dart';
import '../../invisible_expense/presentation/mobile/subscription_checklist_screen.dart';
import '../../invisible_expense/presentation/web/leakage_dashboard_screen.dart';

// ── Trend range ───────────────────────────────────────────────────────────────

enum _TrendRange {
  threeMonths,
  sixMonths,
  twelveMonths,
  twentyFourMonths;

  String get label => switch (this) {
        _TrendRange.threeMonths => '3M',
        _TrendRange.sixMonths => '6M',
        _TrendRange.twelveMonths => '12M',
        _TrendRange.twentyFourMonths => '24M',
      };

  int get months => switch (this) {
        _TrendRange.threeMonths => 3,
        _TrendRange.sixMonths => 6,
        _TrendRange.twelveMonths => 12,
        _TrendRange.twentyFourMonths => 24,
      };

  String get trendSectionLabel => switch (this) {
        _TrendRange.threeMonths => 'Last 3 Months',
        _TrendRange.sixMonths => 'Last 6 Months',
        _TrendRange.twelveMonths => 'Last 12 Months',
        _TrendRange.twentyFourMonths => 'Last 24 Months',
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  _TrendRange _trendRange = _TrendRange.sixMonths;

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

  @override
  Widget build(BuildContext context) {
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

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
      body: ResponsiveLayout(
        mobile: _MobileReportsView(
          monthKey: _monthKey,
          currency: currency,
          ref: ref,
          trendRange: _trendRange,
          onRangeChanged: (r) => setState(() => _trendRange = r),
        ),
        web: _WebReportsView(
          monthKey: _monthKey,
          currency: currency,
          ref: ref,
          trendRange: _trendRange,
          onRangeChanged: (r) => setState(() => _trendRange = r),
        ),
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
        ),
        Text(label, style: AppTextStyles.titleLarge),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded,
              color: canGoNext
                  ? null
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE VIEW — simplified layout
// ─────────────────────────────────────────────────────────────────────────────

class _MobileReportsView extends ConsumerWidget {
  const _MobileReportsView({
    required this.monthKey,
    required this.currency,
    required this.ref,
    required this.trendRange,
    required this.onRangeChanged,
  });

  final String monthKey;
  final String currency;
  final WidgetRef ref;
  final _TrendRange trendRange;
  final ValueChanged<_TrendRange> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final summaryAsync = widgetRef.watch(financialSummaryProvider(monthKey));
    final categoryAsync = widgetRef.watch(categorySpendingProvider(monthKey));
    final trendAsync = widgetRef.watch(monthlyTrendProvider(trendRange.months));

    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Summary cards ──────────────────────────────────────────────
          summaryAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) =>
                _ErrorCard(message: 'Could not load summary'),
            data: (summary) => _SummaryGrid(
              summary: summary,
              currency: currency,
              compact: true,
            ),
          ),
          const SizedBox(height: 16),

          // ── Top expense categories ─────────────────────────────────────
          _SectionHeader(title: 'Expense by Category'),
          const SizedBox(height: 8),
          categoryAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Could not load categories'),
            data: (categories) => categories.isEmpty
                ? _EmptyCard(message: 'No expenses this month.')
                : Column(
                    children: categories
                        .take(5)
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _CategoryRow(
                                  item: c, currency: currency),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ── Category Spending Donut ────────────────────────────────────
          categoryAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (cats) => cats.isEmpty
                ? const SizedBox.shrink()
                : _CategoryDonutChart(
                    categories: cats, currency: currency),
          ),
          const SizedBox(height: 16),

          // ── Compact range selector ─────────────────────────────────────
          _TrendRangeSelector(value: trendRange, onChanged: onRangeChanged),
          const SizedBox(height: 8),

          // ── Monthly trend ──────────────────────────────────────────────
          _SectionHeader(title: 'Monthly Trend — ${trendRange.trendSectionLabel}'),
          const SizedBox(height: 8),
          trendAsync.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: 'Could not load trend'),
            data: (trend) => _TrendTable(trend: trend, currency: currency),
          ),
          const SizedBox(height: 12),

          // ── Charts row: Cash Flow Trend + Monthly Balance ─────────────
          trendAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (trend) => LayoutBuilder(
              builder: (_, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final flowChart = _CashFlowTrendChart(
                    trend: trend,
                    currency: currency,
                    rangeLabel: trendRange.trendSectionLabel);
                final balanceChart = _MonthlyBalanceBarChart(
                    trend: trend, currency: currency);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: flowChart),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: balanceChart),
                    ],
                  );
                }
                return Column(
                  children: [
                    flowChart,
                    const SizedBox(height: AppSpacing.md),
                    balanceChart,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Savings & Debt summaries ───────────────────────────────────
          _SavingsDebtSummary(currency: currency, widgetRef: widgetRef),
          const SizedBox(height: 16),

          // ── Invisible Expense Audit ────────────────────────────────────
          _AuditEntryCard(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const SubscriptionChecklistScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Export ────────────────────────────────────────────────────────
          _ExportEntryCard(onTap: () => context.push(RouteNames.export)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB VIEW — full analytics layout
// ─────────────────────────────────────────────────────────────────────────────

class _WebReportsView extends ConsumerWidget {
  const _WebReportsView({
    required this.monthKey,
    required this.currency,
    required this.ref,
    required this.trendRange,
    required this.onRangeChanged,
  });

  final String monthKey;
  final String currency;
  final WidgetRef ref;
  final _TrendRange trendRange;
  final ValueChanged<_TrendRange> onRangeChanged;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final summaryAsync = widgetRef.watch(financialSummaryProvider(monthKey));
    final categoryAsync = widgetRef.watch(categorySpendingProvider(monthKey));
    final incomeAsync = widgetRef.watch(topIncomeProvider(monthKey));
    final trendAsync = widgetRef.watch(monthlyTrendProvider(trendRange.months));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.responsiveMaxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 4 summary cards ──────────────────────────────────────────
            summaryAsync.when(
              loading: () =>
                  const _LoadingCard(),
              error: (e, _) =>
                  _ErrorCard(message: 'Could not load summary'),
              data: (summary) =>
                  _SummaryGrid(summary: summary, currency: currency),
            ),
            const SizedBox(height: 20),

            // ── Two-column content ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Category spending + Monthly trend
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      FintechCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionHeader(title: 'Expense by Category'),
                            const SizedBox(height: 12),
                            categoryAsync.when(
                              loading: () => const _LoadingCard(),
                              error: (e, _) => _ErrorCard(
                                  message: 'Could not load categories'),
                              data: (cats) => cats.isEmpty
                                  ? _EmptyCard(
                                      message: 'No expenses this month.')
                                  : Column(
                                      children: cats
                                          .map((c) => Padding(
                                                padding: const EdgeInsets
                                                    .only(bottom: 8),
                                                child: _CategoryRow(
                                                    item: c,
                                                    currency: currency),
                                              ))
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // ── Category Spending Donut ───────────────────────
                      categoryAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (cats) => cats.isEmpty
                            ? const SizedBox.shrink()
                            : _CategoryDonutChart(
                                categories: cats, currency: currency),
                      ),
                      const SizedBox(height: 8),
                      // ── Compact range selector ────────────────────────
                      _TrendRangeSelector(
                          value: trendRange, onChanged: onRangeChanged),
                      const SizedBox(height: 8),
                      FintechCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionHeader(title: 'Monthly Trend — ${trendRange.trendSectionLabel}'),
                            const SizedBox(height: 12),
                            trendAsync.when(
                              loading: () => const _LoadingCard(),
                              error: (e, _) =>
                                  _ErrorCard(message: 'Could not load trend'),
                              data: (trend) =>
                                  _TrendTable(trend: trend, currency: currency),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Charts row: Cash Flow Trend + Monthly Balance ─
                      trendAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (trend) => LayoutBuilder(
                          builder: (_, constraints) {
                            final isWide = constraints.maxWidth >= 900;
                            final flowChart = _CashFlowTrendChart(
                                trend: trend,
                                currency: currency,
                                rangeLabel: trendRange.trendSectionLabel);
                            final balanceChart = _MonthlyBalanceBarChart(
                                trend: trend, currency: currency);
                            if (isWide) {
                              return Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: flowChart),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(child: balanceChart),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                flowChart,
                                const SizedBox(height: AppSpacing.md),
                                balanceChart,
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right: Top income categories + savings + debt
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      FintechCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionHeader(title: 'Top Income Sources'),
                            const SizedBox(height: 12),
                            incomeAsync.when(
                              loading: () => const _LoadingCard(),
                              error: (e, _) => _ErrorCard(
                                  message: 'Could not load income'),
                              data: (cats) => cats.isEmpty
                                  ? _EmptyCard(
                                      message: 'No income this month.')
                                  : Column(
                                      children: cats
                                          .map((c) => Padding(
                                                padding: const EdgeInsets
                                                    .only(bottom: 8),
                                                child: _CategoryRow(
                                                    item: c,
                                                    currency: currency,
                                                    isIncome: true),
                                              ))
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SavingsDebtSummary(
                          currency: currency, widgetRef: widgetRef),
                      const SizedBox(height: 12),
                      _AuditEntryCard(
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => const LeakageDashboardScreen(),
                          ),
                        ),
                        isWeb: true,
                      ),
                      const SizedBox(height: 8),
                      _ExportEntryCard(
                        onTap: () => context.push(RouteNames.export),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.summary,
    required this.currency,
    this.compact = false,
  });

  final FinancialSummaryModel summary;
  final String currency;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final balancePositive = summary.netBalance >= 0;
    final budgetOver = summary.hasBudgets && summary.budgetRemaining < 0;
    final screenW = MediaQuery.sizeOf(context).width;

    // Compact mode: single-column below 430 px (prevents truncation on narrow
    // phones), 2-column at or above 430 px with FittedBox on money values.
    final use2Col = !compact || screenW >= 430;
    final cardW = (compact && use2Col) ? (screenW - 40) / 2 : null;

    // Wraps MoneyText in FittedBox when 2-column layout constrains width.
    Widget moneyVal(double amount, Color color) {
      final text = MoneyText(
        amount: amount,
        currency: currency,
        variant: MoneyVariant.large,
        color: color,
      );
      return (compact && use2Col)
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: text,
            )
          : text;
    }

    final cards = [
      MetricCard(
        icon: Icons.arrow_upward_rounded,
        iconColor: AppColors.success,
        title: 'Income',
        valueWidget: moneyVal(summary.totalIncome, AppColors.success),
      ),
      MetricCard(
        icon: Icons.arrow_downward_rounded,
        iconColor: AppColors.danger,
        title: 'Expense',
        valueWidget: moneyVal(summary.totalExpense, AppColors.danger),
      ),
      MetricCard(
        icon: balancePositive
            ? Icons.account_balance_wallet_rounded
            : Icons.warning_rounded,
        iconColor: balancePositive ? AppColors.primary : AppColors.danger,
        title: 'Net Balance',
        valueWidget: moneyVal(
          summary.netBalance.abs(),
          balancePositive ? AppColors.primary : AppColors.danger,
        ),
        subtitle: balancePositive ? 'Positive' : 'Deficit',
      ),
      MetricCard(
        icon: Icons.pie_chart_rounded,
        iconColor: budgetOver ? AppColors.danger : AppColors.warning,
        title: 'Budget Left',
        valueWidget: summary.hasBudgets
            ? moneyVal(
                summary.budgetRemaining.abs(),
                budgetOver ? AppColors.danger : AppColors.warning,
              )
            : null,
        value: summary.hasBudgets ? null : 'No budgets',
        subtitle: summary.hasBudgets && budgetOver ? 'Over budget' : null,
      ),
    ];

    // Single-column for narrow mobile screens — no truncation risk.
    if (compact && !use2Col) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: c,
                ))
            .toList(),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: cards
          .map((c) => SizedBox(width: cardW, child: c))
          .toList(),
    );
  }
}

// ── Category row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.currency,
    this.isIncome = false,
  });

  final CategorySpendingModel item;
  final String currency;
  final bool isIncome;

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.success : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.categoryName,
                style: AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            MoneyText(
              amount: item.totalSpent,
              currency: currency,
              variant: MoneyVariant.small,
              color: color,
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Text(
                item.percentLabel,
                style: AppTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: item.percentage.clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }
}

// ── Trend table ───────────────────────────────────────────────────────────────

/// Scrollable income/expense/balance table.
///
/// Horizontal scroll: activates when the container is narrower than
/// 4 × 120 px = 480 px (narrow phones).
/// Vertical scroll: content is capped at 320 px so long history ranges
/// (12 / 24 / All Available) do not push other sections off screen.
///
/// The header row is inside the horizontal scroll but outside the vertical
/// scroll, so it stays visible while paging through many months.
class _TrendTable extends StatefulWidget {
  const _TrendTable({required this.trend, required this.currency});

  final List<MonthlyTrendModel> trend;
  final String currency;

  @override
  State<_TrendTable> createState() => _TrendTableState();
}

class _TrendTableState extends State<_TrendTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  /// Minimum width of each column.  4 columns → minimum table width = 480 px.
  static const _colMin = 120.0;

  /// Estimated height per data row (padding 8×2 + caption text ~12 + headroom).
  static const _kRowHeight = 36.0;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trend.every((t) => t.income == 0 && t.expense == 0)) {
      return _EmptyCard(message: 'No transaction data in this period.');
    }

    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Expand columns to fill available width; never shrink below _colMin.
        final colW =
            (constraints.maxWidth / 4).clamp(_colMin, double.infinity);

        // ── Cell helpers ────────────────────────────────────────────────────

        Widget cell(Widget child, {bool right = false}) => SizedBox(
              width: colW,
              child: right
                  ? Align(alignment: Alignment.centerRight, child: child)
                  : child,
            );

        Widget headerCell(String label) => cell(
              Text(label,
                  style: AppTypography.label
                      .copyWith(color: cs.onSurfaceVariant)),
              right: label != 'Month',
            );

        // ── Header row (inside horizontal scroll, outside vertical scroll) ─

        final header = Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            headerCell('Month'),
            headerCell('Income'),
            headerCell('Expense'),
            headerCell('Balance'),
          ]),
        );

        // ── Data rows (newest first) ────────────────────────────────────────

        final rows = widget.trend.reversed.map((t) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(children: [
              cell(Text(t.monthLabel,
                  style: AppTypography.caption
                      .copyWith(color: cs.onSurface))),
              cell(
                Text(
                  '${widget.currency} ${t.income.toStringAsFixed(0)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.success),
                ),
                right: true,
              ),
              cell(
                Text(
                  '${widget.currency} ${t.expense.toStringAsFixed(0)}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.danger),
                ),
                right: true,
              ),
              cell(
                Text(
                  '${widget.currency} ${t.balance.abs().toStringAsFixed(0)}',
                  style: AppTypography.caption.copyWith(
                    color: t.isPositive
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
                right: true,
              ),
            ]),
          );
        }).toList();

        // ── Layout: horizontal scroll wraps header + vertical scroll ────────

        return Scrollbar(
          controller: _horizontalController,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              // Fix the inner width so both header and data rows align.
              width: colW * 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const Divider(height: 8),
                  // Vertical scroll area — height = rowHeight × min(months, 6).
                  Scrollbar(
                    controller: _verticalController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: _kRowHeight *
                              widget.trend.length.clamp(1, 6)),
                      child: SingleChildScrollView(
                        controller: _verticalController,
                        scrollDirection: Axis.vertical,
                        child: Column(children: rows),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Savings + Debt summary ────────────────────────────────────────────────────

class _SavingsDebtSummary extends ConsumerWidget {
  const _SavingsDebtSummary({
    required this.currency,
    required this.widgetRef,
  });

  final String currency;
  final WidgetRef widgetRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final debtsAsync = ref.watch(debtsProvider);

    return Column(
      children: [
        // Savings
        FintechCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: 'Saving Goals Progress'),
              const SizedBox(height: 12),
              goalsAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) =>
                    _ErrorCard(message: 'Could not load goals'),
                data: (goals) {
                  if (goals.isEmpty) {
                    return _EmptyCard(message: 'No saving goals yet.');
                  }
                  final totalTarget = goals.fold<double>(
                      0.0, (t, g) => t + g.targetAmount);
                  final totalSaved = goals.fold<double>(
                      0.0, (t, g) => t + g.savedAmount);
                  final percent = totalTarget > 0
                      ? (totalSaved / totalTarget).clamp(0.0, 1.0)
                      : 0.0;
                  return Column(
                    children: [
                      _ProgressRow(
                        label:
                            'Overall (${goals.length} goal${goals.length == 1 ? '' : 's'})',
                        value:
                            '$currency ${totalSaved.toStringAsFixed(2)} / '
                            '$currency ${totalTarget.toStringAsFixed(2)}',
                        progress: percent,
                        color: AppColors.success,
                      ),
                      ...goals.take(3).map((g) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _ProgressRow(
                              label: g.title,
                              value: g.percentLabel,
                              progress: g.clampedPercent,
                              color: g.isCompleted
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          )),
                      if (goals.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${goals.length - 3} more',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Debt
        FintechCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionHeader(title: 'Debt Repayment Progress'),
              const SizedBox(height: 12),
              debtsAsync.when(
                loading: () => const _LoadingCard(),
                error: (e, _) =>
                    _ErrorCard(message: 'Could not load debts'),
                data: (debts) {
                  if (debts.isEmpty) {
                    return _EmptyCard(message: 'No debts tracked.');
                  }
                  final totalDebt = debts.fold<double>(
                      0.0, (t, d) => t + d.totalAmount);
                  final totalRemaining = debts.fold<double>(
                      0.0, (t, d) => t + d.remainingAmount);
                  final totalPaid = totalDebt - totalRemaining;
                  final percent = totalDebt > 0
                      ? (totalPaid / totalDebt).clamp(0.0, 1.0)
                      : 0.0;
                  return Column(
                    children: [
                      _ProgressRow(
                        label:
                            'Overall (${debts.length} debt${debts.length == 1 ? '' : 's'})',
                        value:
                            '$currency ${totalPaid.toStringAsFixed(2)} paid / '
                            '$currency ${totalDebt.toStringAsFixed(2)} total',
                        progress: percent,
                        color: AppColors.primary,
                      ),
                      ...debts.take(3).map((d) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _ProgressRow(
                              label: d.title,
                              value: d.percentLabel,
                              progress: d.clampedPercent,
                              color: d.isSettled
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          )),
                      if (debts.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${debts.length - 3} more',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis),
            ),
            Text(value,
                style: AppTextStyles.bodySmall
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

// ── Tiny helpers ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.heading.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 28,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.caption
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Invisible Expense Audit entry card ────────────────────────────────────────

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.onTap, this.isWeb = false});

  final VoidCallback onTap;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FintechCard(
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
                Icons.manage_search_rounded,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invisible Expense Audit',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    isWeb
                        ? 'Open the full leakage dashboard — detect forgotten subscriptions and micro-habits.'
                        : 'Check for forgotten subscriptions and repeated micro-spending.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Export entry card ─────────────────────────────────────────────────────────

class _ExportEntryCard extends StatelessWidget {
  const _ExportEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FintechCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Reports', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Download transactions, budgets, goals, debts, and monthly summary as CSV or PDF.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ── Trend range selector ─────────────────────────────────────────────────────

/// Moomoo-style compact chip row: 3M / 6M / 12M / 24M.
/// Placed directly above the Monthly Trend section in both views.
class _TrendRangeSelector extends StatelessWidget {
  const _TrendRangeSelector({
    required this.value,
    required this.onChanged,
  });

  final _TrendRange value;
  final ValueChanged<_TrendRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in _TrendRange.values)
          _RangeChip(
            label: r.label,
            selected: r == value,
            onTap: () => onChanged(r),
          ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : cs.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? Colors.white : cs.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Y-axis helpers ────────────────────────────────────────────────────────────

class _YAxisParams {
  _YAxisParams({
    required this.minY,
    required this.maxY,
    required this.interval,
    required this.ticks,
  });
  final double minY;
  final double maxY;
  final double interval;
  final List<double> ticks;
}

_YAxisParams _computeYAxisParams(List<double> values) {
  if (values.isEmpty) {
    return _YAxisParams(minY: -1, maxY: 1, interval: 1, ticks: [-1, 0, 1]);
  }
  final dataMax = values.reduce((a, b) => b > a ? b : a);
  final dataMin = values.reduce((a, b) => b < a ? b : a);
  final range = (dataMax - dataMin).clamp(1.0, double.infinity);
  final pad = range * 0.15;
  final minY = dataMin - pad;
  final maxY = dataMax + pad;
  final interval = _niceYInterval(maxY - minY, 4);
  final firstTick = (minY / interval).ceil() * interval;
  final ticks = <double>[];
  var i = 0;
  while (true) {
    final tick = firstTick + i * interval;
    if (tick > maxY + interval * 0.001) break;
    ticks.add(tick);
    i++;
  }
  if (ticks.isEmpty) {
    return _YAxisParams(minY: minY, maxY: maxY, interval: interval, ticks: [minY, maxY]);
  }
  return _YAxisParams(minY: minY, maxY: maxY, interval: interval, ticks: ticks);
}

double _niceYInterval(double range, int target) {
  if (range <= 0) return 1;
  final rough = range / target;
  var v = rough;
  var mag = 1.0;
  if (v >= 10) {
    while (v >= 10) {
      v /= 10;
      mag *= 10;
    }
  } else if (v > 0 && v < 1) {
    while (v < 1) {
      v *= 10;
      mag /= 10;
    }
  }
  final mult = v < 1.5 ? 1.0 : v < 3.0 ? 2.0 : v < 7.0 ? 5.0 : 10.0;
  return mult * mag;
}

// ── Fixed Y-axis label column ─────────────────────────────────────────────────

/// Renders Y-axis tick labels as a fixed-width column that sits OUTSIDE the
/// horizontal scroll view.  Uses [LayoutBuilder] to match the chart's total
/// height and calculates each label's top-offset from [minY]/[maxY] and the
/// chart's bottom reserved space (where the X-axis lives).
class _FixedYAxis extends StatelessWidget {
  const _FixedYAxis({
    required this.minY,
    required this.maxY,
    required this.ticks,
  });

  final double minY;
  final double maxY;
  final List<double> ticks;

  // Space reserved by fl_chart for the bottom (X-axis) titles.
  static const _bottomReserved = 22.0;

  static String _fmtY(double v) {
    final absV = v.abs();
    if (absV >= 1000) {
      return '${(v / 1000).toStringAsFixed(absV >= 10000 ? 0 : 1)}K';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = AppTypography.caption.copyWith(
      color: cs.onSurface.withValues(alpha: 0.55),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        final plotH = constraints.maxHeight - _bottomReserved;
        final yRange = maxY - minY;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final tick in ticks)
              Positioned(
                // Center label text at the exact Y fraction within the plot area.
                top: yRange > 0
                    ? (1.0 - (tick - minY) / yRange) * plotH - 8
                    : 0,
                left: 0,
                right: 4,
                child: Text(
                  _fmtY(tick),
                  style: labelStyle,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Cash Flow Trend chart ─────────────────────────────────────────────────────

/// Line chart showing income, expense, and net-balance trends.
/// Horizontally scrollable when months > 12; auto-scrolls to the newest point.
class _CashFlowTrendChart extends StatefulWidget {
  const _CashFlowTrendChart({
    required this.trend,
    required this.currency,
    required this.rangeLabel,
  });

  final List<MonthlyTrendModel> trend;
  final String currency;
  final String rangeLabel;

  @override
  State<_CashFlowTrendChart> createState() => _CashFlowTrendChartState();
}

class _CashFlowTrendChartState extends State<_CashFlowTrendChart> {
  final _scrollController = ScrollController();
  static const _visibleCapacity = 12;

  @override
  void initState() {
    super.initState();
    _maybeScrollToEnd();
  }

  @override
  void didUpdateWidget(_CashFlowTrendChart old) {
    super.didUpdateWidget(old);
    if (widget.trend.length != old.trend.length) {
      _maybeScrollToEnd();
    }
  }

  void _maybeScrollToEnd() {
    if (widget.trend.length > _visibleCapacity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.trend.isEmpty ||
        widget.trend.every((t) => t.income == 0 && t.expense == 0);

    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cash Flow Trend',
            style: AppTypography.heading.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            widget.rangeLabel,
            style: AppTypography.caption
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEmpty)
            const _EmptyCard(message: 'No transaction data in this period.')
          else ...[
            const Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                _LegendChip(color: AppColors.success, label: 'Income'),
                _LegendChip(color: AppColors.danger, label: 'Expense'),
                _LegendChip(color: AppColors.primary, label: 'Net Balance'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final avail = constraints.maxWidth;
                final count = widget.trend.length;
                final needsScroll = count > _visibleCapacity;
                const yAxisW = 52.0;
                const chartH = 180.0;
                final plotW = avail - yAxisW;
                final chartW = needsScroll
                    ? (plotW / _visibleCapacity) * count
                    : plotW;

                final allY = [
                  ...widget.trend.map((t) => t.income),
                  ...widget.trend.map((t) => t.expense),
                  ...widget.trend.map((t) => t.balance),
                ];
                final params = _computeYAxisParams(allY);

                final chartBox = SizedBox(
                  height: chartH,
                  width: chartW,
                  child: _buildChart(context, params),
                );
                final scrollablePlot = needsScroll
                    ? Scrollbar(
                        controller: _scrollController,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: chartBox,
                        ),
                      )
                    : chartBox;

                return SizedBox(
                  height: chartH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: yAxisW,
                        child: _FixedYAxis(
                          minY: params.minY,
                          maxY: params.maxY,
                          ticks: params.ticks,
                        ),
                      ),
                      Expanded(child: scrollablePlot),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, _YAxisParams params) {
    // Oldest-first — index 0 = oldest, index N-1 = newest (left → right).
    final cs = Theme.of(context).colorScheme;
    final ordered = widget.trend.toList();

    if (ordered.length < 2) {
      return const _EmptyCard(message: 'Not enough data to display.');
    }

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final balanceSpots = <FlSpot>[];

    for (var i = 0; i < ordered.length; i++) {
      final t = ordered[i];
      incomeSpots.add(FlSpot(i.toDouble(), t.income));
      expenseSpots.add(FlSpot(i.toDouble(), t.expense));
      balanceSpots.add(FlSpot(i.toDouble(), t.balance));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: params.interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outline.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          // Left titles are rendered by the fixed _FixedYAxis widget outside
          // the scroll view — disable them here to avoid duplication.
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= ordered.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ordered[i].monthLabel.split(' ').first,
                    style: AppTypography.caption
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: cs.outline),
            left: BorderSide(color: cs.outline),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              const names = ['Income', 'Expense', 'Net Balance'];
              return spots.map((spot) {
                final name = spot.barIndex < names.length
                    ? names[spot.barIndex]
                    : '';
                return LineTooltipItem(
                  '$name\n${widget.currency} ${spot.y.toStringAsFixed(2)}',
                  TextStyle(
                    color: spot.bar.color ?? cs.onInverseSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        // Extend X range by ±0.5 so first/last month labels are not clipped.
        minX: -0.5,
        maxX: (ordered.length - 1).toDouble() + 0.5,
        minY: params.minY,
        maxY: params.maxY,
        lineBarsData: [
          // Income — solid green with subtle fill
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.success,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.success,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.success.withValues(alpha: 0.06),
            ),
          ),
          // Expense — solid red with subtle fill
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.danger,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.danger,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.danger.withValues(alpha: 0.04),
            ),
          ),
          // Net Balance — dashed blue, no fill
          LineChartBarData(
            spots: balanceSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dashArray: [4, 3],
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.primary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

// ── Legend chip ───────────────────────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Category Spending Donut Chart ─────────────────────────────────────────────

/// Donut chart showing top-5 spending categories plus an "Others" segment.
/// Uses the same [CategorySpendingModel] list already shown in [_CategoryRow].
class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({
    required this.categories,
    required this.currency,
  });

  final List<CategorySpendingModel> categories;
  final String currency;

  // Fixed segment colour palette — cycles if somehow more than 5 categories.
  static const _palette = [
    AppColors.primary,
    AppColors.success,
    AppColors.danger,
    AppColors.warning,
    Color(0xFF8B5CF6), // violet
  ];

  static const _othersColor = Color(0xFFCBD5E1); // light-slate for "Others"

  @override
  Widget build(BuildContext context) {
    final top5 = categories.take(5).toList();
    final othersPercent = categories
        .skip(5)
        .fold<double>(0.0, (s, c) => s + c.percentage);
    final hasOthers = othersPercent > 0.001;

    // Build PieChart sections from provider-computed percentages.
    final sections = <PieChartSectionData>[
      for (var i = 0; i < top5.length; i++)
        _section(
          value: top5[i].percentage * 100,
          color: _palette[i % _palette.length],
        ),
      if (hasOthers)
        _section(
          value: (othersPercent * 100).clamp(0.0, 100.0),
          color: _othersColor,
          isOthers: true,
          othersLabelColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    ];

    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Breakdown',
            style: AppTypography.heading.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            'Top ${top5.length} categories by spending',
            style: AppTypography.caption
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 380;
              final chart = SizedBox(
                width: 160,
                height: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 46,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
              );
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < top5.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _DonutLegendRow(
                        color: _palette[i % _palette.length],
                        label: top5[i].categoryName,
                        percent: top5[i].percentLabel,
                      ),
                    ),
                  if (hasOthers)
                    _DonutLegendRow(
                      color: _othersColor,
                      label: 'Others',
                      percent:
                          '${(othersPercent * 100).toStringAsFixed(1)}%',
                    ),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    chart,
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: legend),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: chart),
                  const SizedBox(height: AppSpacing.lg),
                  legend,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static PieChartSectionData _section({
    required double value,
    required Color color,
    bool isOthers = false,
    Color? othersLabelColor,
  }) {
    final showLabel = value >= 8;
    return PieChartSectionData(
      value: value,
      color: color,
      radius: 52,
      title: showLabel ? '${value.toStringAsFixed(0)}%' : '',
      titleStyle: TextStyle(
        color: isOthers
            ? (othersLabelColor ?? AppColors.textSecondary)
            : Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
      titlePositionPercentageOffset: 0.62,
    );
  }
}

// ── Donut chart legend row ────────────────────────────────────────────────────

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({
    required this.color,
    required this.label,
    required this.percent,
  });

  final Color color;
  final String label;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption
                .copyWith(color: Theme.of(context).colorScheme.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          percent,
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Monthly Balance Bar Chart ─────────────────────────────────────────────────

/// Grouped bar chart showing Income, Expense, and Net Balance per month.
/// Horizontally scrollable when months > 12; auto-scrolls to the newest point.
class _MonthlyBalanceBarChart extends StatefulWidget {
  const _MonthlyBalanceBarChart({
    required this.trend,
    required this.currency,
  });

  final List<MonthlyTrendModel> trend;
  final String currency;

  @override
  State<_MonthlyBalanceBarChart> createState() =>
      _MonthlyBalanceBarChartState();
}

class _MonthlyBalanceBarChartState extends State<_MonthlyBalanceBarChart> {
  final _scrollController = ScrollController();
  static const _visibleCapacity = 12;

  @override
  void initState() {
    super.initState();
    _maybeScrollToEnd();
  }

  @override
  void didUpdateWidget(_MonthlyBalanceBarChart old) {
    super.didUpdateWidget(old);
    if (widget.trend.length != old.trend.length) {
      _maybeScrollToEnd();
    }
  }

  void _maybeScrollToEnd() {
    if (widget.trend.length > _visibleCapacity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.trend.isEmpty ||
        widget.trend.every((t) => t.income == 0 && t.expense == 0);

    return FintechCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Balance',
            style: AppTypography.heading.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            'Income · Expense · Net Balance',
            style: AppTypography.caption
                .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _LegendChip(color: AppColors.success, label: 'Income'),
              _LegendChip(color: AppColors.danger, label: 'Expense'),
              _LegendChip(color: AppColors.primary, label: 'Balance'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isEmpty)
            const _EmptyCard(message: 'No transaction data in this period.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final avail = constraints.maxWidth;
                final count = widget.trend.length;
                final needsScroll = count > _visibleCapacity;
                const yAxisW = 52.0;
                const chartH = 200.0;
                final plotW = avail - yAxisW;
                final chartW = needsScroll
                    ? (plotW / _visibleCapacity) * count
                    : plotW;

                final allY = [
                  ...widget.trend.map((t) => t.income),
                  ...widget.trend.map((t) => t.expense),
                  ...widget.trend.map((t) => t.balance),
                ];
                final params = _computeYAxisParams(allY);

                final chartBox = SizedBox(
                  height: chartH,
                  width: chartW,
                  child: _buildChart(context, params),
                );
                final scrollablePlot = needsScroll
                    ? Scrollbar(
                        controller: _scrollController,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: chartBox,
                        ),
                      )
                    : chartBox;

                return SizedBox(
                  height: chartH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: yAxisW,
                        child: _FixedYAxis(
                          minY: params.minY,
                          maxY: params.maxY,
                          ticks: params.ticks,
                        ),
                      ),
                      Expanded(child: scrollablePlot),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, _YAxisParams params) {
    // Oldest-first — same ordering contract as _CashFlowTrendChart.
    final cs = Theme.of(context).colorScheme;
    final ordered = widget.trend.toList();

    final groups = <BarChartGroupData>[
      for (var i = 0; i < ordered.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 3,
          barRods: [
            // Income bar (always ≥ 0, goes upward)
            BarChartRodData(
              toY: ordered[i].income,
              color: AppColors.success,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            // Expense bar (always ≥ 0, goes upward)
            BarChartRodData(
              toY: ordered[i].expense,
              color: AppColors.danger,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
            ),
            // Balance bar — positive goes up, negative goes down.
            BarChartRodData(
              toY: ordered[i].balance,
              color: ordered[i].balance >= 0
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.55),
              width: 8,
              borderRadius: ordered[i].balance >= 0
                  ? const BorderRadius.vertical(top: Radius.circular(3))
                  : const BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        barGroups: groups,
        alignment: BarChartAlignment.spaceEvenly,
        maxY: params.maxY,
        minY: params.minY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: params.interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outline.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: cs.outline),
            left: BorderSide(color: cs.outline),
          ),
        ),
        titlesData: FlTitlesData(
          // Left titles rendered by fixed _FixedYAxis widget outside scroll.
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= ordered.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    ordered[i].monthLabel.split(' ').first,
                    style: AppTypography.caption
                        .copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              const labels = ['Income', 'Expense', 'Balance'];
              final label =
                  rodIndex < labels.length ? labels[rodIndex] : '';
              return BarTooltipItem(
                '$label\n${widget.currency} ${rod.toY.toStringAsFixed(2)}',
                TextStyle(
                  color: rod.color ?? cs.onInverseSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
