import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/responsive/responsive_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/debt_model.dart';
import 'add_debt_payment_screen.dart';
import 'debt_detail_screen.dart';
import 'debt_form_screen.dart';
import 'debt_provider.dart';

class DebtScreen extends ConsumerWidget {
  const DebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

    return Scaffold(
      appBar: AppBar(title: const Text('Debt / PTPTN')),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Failed to load debts',
              style: AppTextStyles.bodyMedium),
        ),
        data: (debts) => ResponsiveContent(child: Column(
          children: [
            _SummaryRow(debts: debts, currency: currency),
            const Divider(height: 1),
            Expanded(
              child: debts.isEmpty
                  ? EmptyState(
                      title: 'No debts tracked',
                      subtitle:
                          'Tap + to add a loan, credit card, or PTPTN debt.',
                      icon: Icons.account_balance_rounded,
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: debts.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _DebtCard(
                        debt: debts[i],
                        currency: currency,
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => DebtDetailScreen(
                              debtId: debts[i].debtId,
                              initialDebt: debts[i],
                            ),
                          ),
                        ),
                        onAddPayment: () =>
                            Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => AddDebtPaymentScreen(
                              debtId: debts[i].debtId,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const DebtFormScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Debt'),
        backgroundColor: AppColors.expense,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.debts, required this.currency});

  final List<DebtModel> debts;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final totalDebt =
        debts.fold<double>(0.0, (t, d) => t + d.totalAmount);
    final totalRemaining =
        debts.fold<double>(0.0, (t, d) => t + d.remainingAmount);
    final totalPaid = totalDebt - totalRemaining;
    final overallPercent =
        totalDebt > 0 ? (totalPaid / totalDebt).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SummaryChip(
                label: 'Total Debt',
                value: '$currency ${totalDebt.toStringAsFixed(2)}',
                color: AppColors.expense,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Remaining',
                value: '$currency ${totalRemaining.toStringAsFixed(2)}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Paid',
                value: '$currency ${totalPaid.toStringAsFixed(2)}',
                color: AppColors.income,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Overall Repayment',
                style: AppTextStyles.labelLarge
                    .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '${(overallPercent * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overallPercent,
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary),
              minHeight: 8,
            ),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                fontSize: 10,
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

// ── Debt card ─────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.currency,
    required this.onTap,
    required this.onAddPayment,
  });

  final DebtModel debt;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onAddPayment;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month]} ${d.year}';

  Color get _progressColor {
    if (debt.isSettled) return AppColors.income;
    if (debt.isOverdue) return AppColors.expense;
    if (debt.clampedPercent >= 0.75) return AppColors.income;
    if (debt.clampedPercent >= 0.5) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
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
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _progressColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      debt.isSettled
                          ? Icons.check_circle_rounded
                          : Icons.account_balance_rounded,
                      color: _progressColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(debt.title,
                            style: AppTextStyles.titleMedium),
                        Text(
                          'Total: $currency '
                          '${debt.totalAmount.toStringAsFixed(2)} • '
                          'Monthly: $currency '
                          '${debt.monthlyDue.toStringAsFixed(2)}',
                          style: AppTextStyles.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (debt.isSettled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.income.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.income
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Settled',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.income),
                      ),
                    )
                  else if (debt.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.expense
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Overdue',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.expense),
                      ),
                    )
                  else
                    Text(
                      debt.percentLabel,
                      style: AppTextStyles.titleMedium
                          .copyWith(color: _progressColor),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Progress bar ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: debt.clampedPercent,
                  backgroundColor:
                      _progressColor.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_progressColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),

              // ── Paid / Remaining ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid: $currency '
                    '${debt.paidAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    debt.isSettled
                        ? 'Fully settled!'
                        : 'Remaining: $currency '
                            '${debt.remainingAmount.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: debt.isSettled
                          ? AppColors.income
                          : AppColors.textSecondary,
                      fontWeight: debt.isSettled
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Due date + quick pay ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Due: ${_fmtDate(debt.dueDate)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11,
                      color: debt.isOverdue
                          ? AppColors.expense
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (!debt.isSettled)
                    TextButton.icon(
                      onPressed: onAddPayment,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: const Text('Pay',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
