import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/debt_model.dart';
import '../domain/debt_payment_model.dart';
import 'add_debt_payment_screen.dart';
import 'debt_form_screen.dart';
import 'debt_provider.dart';

/// Full detail view for one debt: progress, payment history, quick pay.
///
/// Watches [debtByIdProvider] in real time — auto-pops back to the debt
/// list when the debt is deleted from the edit form.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({
    super.key,
    required this.debtId,
    required this.initialDebt,
  });

  final String debtId;
  final DebtModel initialDebt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(debtByIdProvider(debtId));
    final paymentsAsync = ref.watch(paymentsProvider(debtId));
    final currency =
        ref.watch(currentUserProfileProvider).asData?.value?.currency ??
            'MYR';

    final debt = debtAsync.asData?.value ?? initialDebt;

    // Auto-pop when debt is deleted
    if (debtAsync.asData != null && debtAsync.asData!.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit debt',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => DebtFormScreen(existingDebt: debt),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _DebtProgressCard(debt: debt, currency: currency),
          const SizedBox(height: 16),

          if (debt.note.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(debt.note,
                        style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SectionHeader(
            title: 'Payment History',
            actionLabel: 'Add Payment',
            onAction: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AddDebtPaymentScreen(debtId: debtId),
              ),
            ),
          ),
          const SizedBox(height: 8),

          paymentsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load payments',
                style: AppTextStyles.bodyMedium),
            data: (payments) => payments.isEmpty
                ? EmptyState(
                    title: 'No payments recorded',
                    subtitle: 'Tap Add Payment to log your first repayment.',
                    icon: Icons.payment_rounded,
                  )
                : Column(
                    children: payments
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PaymentTile(
                              payment: p,
                              currency: currency,
                              onDelete: () => _confirmDeletePayment(
                                  context, ref, p),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: debt.isSettled
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      AddDebtPaymentScreen(debtId: debtId),
                ),
              ),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Add Payment'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }

  void _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    DebtPaymentModel payment,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text(
          'Remove payment of '
          '${payment.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid =
                  ref.read(authStateChangesProvider).asData?.value?.uid;
              if (uid == null) return;
              try {
                await ref.read(debtServiceProvider).deletePayment(
                    uid, debtId, payment.paymentId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Progress card ─────────────────────────────────────────────────────────────

class _DebtProgressCard extends StatelessWidget {
  const _DebtProgressCard({required this.debt, required this.currency});

  final DebtModel debt;
  final String currency;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month]} ${d.year}';

  Color get _color {
    if (debt.isSettled) return AppColors.income;
    if (debt.isOverdue) return AppColors.expense;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (debt.isSettled) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.income.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.income, size: 16),
                  const SizedBox(width: 6),
                  Text('Debt Fully Settled!',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.income)),
                ],
              ),
            ),
          ] else if (debt.isOverdue) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.expense.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_rounded,
                      color: AppColors.expense, size: 16),
                  const SizedBox(width: 6),
                  Text('Overdue — Due date has passed',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.expense)),
                ],
              ),
            ),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(
                label: 'Paid',
                value: '$currency ${debt.paidAmount.toStringAsFixed(2)}',
                color: AppColors.income,
              ),
              _StatColumn(
                label: 'Remaining',
                value: '$currency ${debt.remainingAmount.toStringAsFixed(2)}',
                color: _color,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: debt.clampedPercent,
                    backgroundColor: _color.withValues(alpha: 0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_color),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                debt.percentLabel,
                style:
                    AppTextStyles.titleMedium.copyWith(color: _color),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              _StatColumn(
                label: 'Total Loan',
                value: '$currency ${debt.totalAmount.toStringAsFixed(2)}',
              ),
              _StatColumn(
                label: 'Monthly Due',
                value: '$currency ${debt.monthlyDue.toStringAsFixed(2)}',
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatColumn(
                label: 'Start Date',
                value: _fmtDate(debt.startDate),
              ),
              _StatColumn(
                label: 'Due Date',
                value: _fmtDate(debt.dueDate),
                color: debt.isOverdue ? AppColors.expense : null,
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.titleMedium
                .copyWith(color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Payment tile ──────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.payment,
    required this.currency,
    required this.onDelete,
  });

  final DebtPaymentModel payment;
  final String currency;
  final VoidCallback onDelete;

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final d = payment.date;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.note.isNotEmpty ? payment.note : 'Repayment',
                  style: AppTextStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${d.day} ${_months[d.month]} ${d.year}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '-$currency ${payment.amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.primary),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.expense,
            tooltip: 'Delete payment',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
